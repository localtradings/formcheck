import 'dart:math' as math;

import 'rep_analyzer.dart';
import 'workout.dart';

enum PlacementView { unknown, side, moveToSide }

final class WorldJoint {
  const WorldJoint(this.x, this.y, this.z, [this.confidence = 1]);
  final double x, y, z, confidence;

  bool get _usable =>
      x.abs() <= 2.5 &&
      y.abs() <= 2.5 &&
      z.abs() <= 2.5 &&
      confidence >= .65 &&
      confidence <= 1;
}

final class PlacementReading {
  const PlacementReading({
    required this.view,
    this.estimatedDegrees,
    required this.blockAssessment,
  });
  const PlacementReading.unknown({this.blockAssessment = false})
    : view = PlacementView.unknown,
      estimatedDegrees = null;

  final PlacementView view;
  final int? estimatedDegrees;
  final bool blockAssessment;
}

enum _ViewEvidence { side, wrong, contradictory, singleSide, incomplete }

typedef _Observation = (_ViewEvidence, double?);
typedef _Axis = ({double x, double y, double z});

/// Estimates side-on placement from a single upright camera frame at a time.
/// A usable near-side chain can support form checks even when the opposite
/// side is hidden. Only stable, agreeing 3D torso axes produce a numeric angle.
final class CameraPlacement {
  CameraPlacement(this.exercise) {
    if (!exercise.cameraSupported) {
      throw ArgumentError.value(exercise, 'exercise');
    }
  }

  final Exercise exercise;
  int? _lastTime;
  double? _aspect;
  _ViewEvidence? _candidate;
  int _candidateSince = 0;
  int _samples = 0;
  bool _blocked = false;
  bool _hasUsableShape = false;
  bool _stableSide = false;
  double? _anchor;
  double _smoothed = 0;
  int _angleSince = 0;
  int _angleSamples = 0;
  int? _reported;

  void reset() {
    _lastTime = null;
    _aspect = null;
    _candidate = null;
    _stableSide = false;
    _blocked = false;
    _hasUsableShape = false;
    _anchor = null;
    _reported = null;
  }

  PlacementReading update(PoseSample sample, List<WorldJoint> world) {
    final now = sample.timestampMs;
    final previous = _lastTime;
    if (now < 0 || previous != null && now <= previous) {
      return const PlacementReading.unknown(blockAssessment: true);
    }
    if (_aspect != sample.aspect ||
        previous != null && now - previous > RepAnalyzer.maxFrameGapMs) {
      reset();
    }
    _lastTime = now;
    _aspect = sample.aspect;
    if (sample.people.length != 1 ||
        sample.people.single.length != 33 ||
        !sample.aspect.isFinite ||
        sample.aspect <= 0) {
      _candidate = null;
      _stableSide = false;
      _blocked = true;
      _hasUsableShape = false;
      _anchor = null;
      return const PlacementReading.unknown(blockAssessment: true);
    }

    final (kind, degrees) = _observe(
      sample.people.single,
      sample.aspect,
      world,
    );
    if (_candidate != kind) {
      _candidate = kind;
      _candidateSince = now;
      _samples = 0;
      _anchor = null;
    }
    _samples++;
    final held = now - _candidateSince;
    _hasUsableShape |=
        kind == _ViewEvidence.side || kind == _ViewEvidence.singleSide;
    _stableSide = kind == _ViewEvidence.side && _samples >= 3 && held >= 300;
    if (kind == _ViewEvidence.wrong || kind == _ViewEvidence.contradictory) {
      _blocked = true;
    } else if (_stableSide ||
        kind == _ViewEvidence.singleSide && _samples >= 4 && held >= 600) {
      _blocked = false;
    }
    final measured = _degrees(
      degrees,
      now,
      previous == null ? 0 : now - previous,
    );
    return PlacementReading(
      view: kind == _ViewEvidence.wrong
          ? PlacementView.moveToSide
          : _stableSide
          ? PlacementView.side
          : PlacementView.unknown,
      estimatedDegrees: measured,
      blockAssessment: _blocked || !_hasUsableShape,
    );
  }

  int? _degrees(double? degrees, int now, int interval) {
    final anchor = _anchor;
    if (degrees == null) {
      _anchor = null;
      _reported = null;
      return null;
    }
    if (anchor == null || (degrees - anchor).abs() > 8) {
      _anchor = _smoothed = degrees;
      _angleSince = now;
      _angleSamples = 1;
      _reported = null;
      return null;
    }
    _angleSamples++;
    _smoothed += (1 - math.exp(-interval / 160)) * (degrees - _smoothed);
    if (now - _angleSince < 320 || _angleSamples < 4) return null;
    if (_reported == null || (_smoothed - _reported!).abs() >= 3.25) {
      _reported = (_smoothed / 5).round() * 5;
    }
    return _reported;
  }

  _Observation _observe(
    List<Joint> image,
    double aspect,
    List<WorldJoint> world,
  ) {
    double? distance(int first, int second) {
      final start = image[first], end = image[second];
      if (!start.visible || !end.visible) return null;
      final dx = (start.x - end.x) * aspect, dy = start.y - end.y;
      return math.sqrt(dx * dx + dy * dy);
    }

    final left = distance(11, 23), right = distance(12, 24);
    final torso = left == null
        ? right ?? 0
        : right == null
        ? left
        : (left + right) / 2;
    final shoulders = distance(11, 12), hips = distance(23, 24);
    if (math.max(torso, math.max(shoulders ?? 0, hips ?? 0)) <
        .035 * math.min(aspect, 1)) {
      return (_ViewEvidence.incomplete, null);
    }
    final shoulderRatio = torso > .025 && shoulders != null
        ? shoulders / torso
        : null;
    final hipRatio = torso > .025 && hips != null ? hips / torso : null;
    final narrow =
        shoulderRatio != null &&
        hipRatio != null &&
        shoulderRatio <= .32 &&
        hipRatio <= .28;
    final wide =
        (shoulderRatio ?? 0) > .79 ||
        (hipRatio ?? 0) > .64 ||
        (shoulderRatio ?? 0) > .55 && (hipRatio ?? 0) > .38;
    final twisted =
        shoulderRatio != null &&
        hipRatio != null &&
        (shoulderRatio > .64 && hipRatio < .15 ||
            shoulderRatio < .17 && hipRatio > .50);
    if (twisted) return (_ViewEvidence.contradictory, null);

    final shoulderAxis = _axis(image, world, 11);
    final hipAxis = _axis(image, world, 23);
    double? bearing;
    if (shoulderAxis != null && hipAxis != null) {
      final agreement =
          shoulderAxis.x * hipAxis.x +
          shoulderAxis.y * hipAxis.y +
          shoulderAxis.z * hipAxis.z;
      if (agreement < .87) return (_ViewEvidence.contradictory, null);
      final shoulderAngle = _bearing(shoulderAxis),
          hipAngle = _bearing(hipAxis);
      if ((shoulderAngle - hipAngle).abs() > 20) {
        return (_ViewEvidence.contradictory, null);
      }
      bearing = (shoulderAngle + hipAngle) / 2;
    }
    final availableAxis = shoulderAxis ?? hipAxis;
    final direction =
        bearing ?? (availableAxis == null ? null : _bearing(availableAxis));
    if (direction != null &&
        (wide && direction > 63 || narrow && direction < 42)) {
      return (_ViewEvidence.contradictory, null);
    }
    // Foreshortening can make the inferred depth change as a person bends.
    // Accept a borderline estimate only with overlapping shoulders AND hips.
    final sideThreshold = _stableSide ? 65 : 72;
    final borderlineSide =
        narrow && bearing != null && bearing >= 58 && bearing < sideThreshold;
    if (wide || bearing != null && bearing < sideThreshold && !borderlineSide) {
      return (_ViewEvidence.wrong, bearing);
    }
    if (bearing == null && direction != null && direction < 42) {
      return (_ViewEvidence.contradictory, null);
    }

    bool hasFullBody = false;
    bool shapeMatches = false;
    for (var side = 0; side < 2; side++) {
      final shoulder = image[11 + side],
          hip = image[23 + side],
          ankle = image[27 + side];
      if (!shoulder.visible || !hip.visible || !ankle.visible) continue;
      final dx = (shoulder.x - ankle.x).abs() * aspect,
          dy = ankle.y - shoulder.y;
      if (math.max(dx, dy.abs()) < .10 * math.min(aspect, 1)) continue;
      hasFullBody = true;
      shapeMatches |= exercise == Exercise.squat
          ? dy > dx * .8 && hip.y < ankle.y && shoulder.y < hip.y
          : dx > dy.abs() * 1.45;
    }
    if (!shapeMatches) {
      return (
        hasFullBody ? _ViewEvidence.contradictory : _ViewEvidence.incomplete,
        null,
      );
    }
    if (bearing != null || narrow) {
      return (_ViewEvidence.side, borderlineSide ? null : bearing);
    }
    if (shoulderRatio != null && hipRatio != null) {
      return (_ViewEvidence.contradictory, null);
    }
    return (_ViewEvidence.singleSide, null);
  }

  static _Axis? _axis(List<Joint> image, List<WorldJoint> world, int start) {
    if (world.length != 33 ||
        !image[start].visible ||
        !image[start + 1].visible) {
      return null;
    }
    final left = world[start], right = world[start + 1];
    if (!left._usable || !right._usable) return null;
    final dx = right.x - left.x, dy = right.y - left.y, dz = right.z - left.z;
    final width = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (width < .065 || width > .85 || dy.abs() > .65 * width) return null;
    return (x: dx / width, y: dy / width, z: dz / width);
  }

  // Azimuth is horizontal. The camera's vertical axis includes shoulder lift
  // and perspective as the torso moves. Phone leveling is checked separately.
  static double _bearing(_Axis axis) =>
      math.atan2(axis.z.abs(), axis.x.abs()) * 180 / math.pi;
}
