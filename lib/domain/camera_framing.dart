import 'dart:collection';
import 'dart:math' as math;

import 'rep_analyzer.dart';
import 'workout.dart';

enum FramingIssue {
  clear,
  searching,
  intermittent,
  multiplePeople,
  tooClose,
  tooFar,
  offCenter,
  missingLegs,
  missingArms,
  missingTorso,
}

enum _Adjustment { hold, widen, tighten }

final class CameraFraming {
  CameraFraming(this.exercise) {
    if (!exercise.cameraSupported) {
      throw ArgumentError.value(exercise, 'exercise');
    }
  }

  static const _adjustmentCooldownMs = 2000;
  final Exercise exercise;
  FramingIssue _issue = FramingIssue.searching;
  FramingIssue _candidate = FramingIssue.searching;
  int _candidateAt = 0;
  _Adjustment _adjustment = _Adjustment.hold;
  int _adjustmentAt = 0;
  _Observation? _baseline;
  int? _lastFrameAt;
  double? _aspect;
  int _nextAdjustmentAt = 0;
  bool _requestedWider = false;
  bool _needsWiderLens = false;
  final _visibilityChanges = ListQueue<int>(4);
  int? _lastPeople;

  FramingIssue get issue {
    final now = _lastFrameAt;
    if (now != null &&
        (_lastPeople ?? 0) < 2 &&
        _visibilityChanges.length == 4 &&
        now - _visibilityChanges.last < 600 &&
        (_issue == FramingIssue.clear ||
            _issue == FramingIssue.searching ||
            _issue == FramingIssue.multiplePeople)) {
      return FramingIssue.intermittent;
    }
    return _issue;
  }

  bool get needsWiderLens => _needsWiderLens;

  void reset() {
    _restartEvidence(0);
    _nextAdjustmentAt = 0;
    _lastFrameAt = null;
    _aspect = null;
    _requestedWider = _needsWiderLens = false;
  }

  void _restartEvidence(int now) {
    _issue = _candidate = FramingIssue.searching;
    _candidateAt = _adjustmentAt = now;
    _adjustment = _Adjustment.hold;
    _baseline = null;
    _visibilityChanges.clear();
    _lastPeople = null;
  }

  double? update(
    PoseSample sample, {
    required double currentZoom,
    required double minZoom,
    required double maxZoom,
    required bool recording,
    required TrackingStatus tracking,
  }) {
    _needsWiderLens = false;
    final now = sample.timestampMs;
    final previous = _lastFrameAt;
    if (now < 0 || previous != null && now <= previous) return null;
    if (!sample.aspect.isFinite || sample.aspect <= 0) {
      reset();
      return null;
    }
    if (previous == null || now - previous > 600 || _aspect != sample.aspect) {
      _restartEvidence(now);
    }
    _lastFrameAt = now;
    _aspect = sample.aspect;
    final count = sample.people.length;
    if (_lastPeople != null && (_lastPeople == 1) != (count == 1)) {
      if (_visibilityChanges.length == 4) _visibilityChanges.removeFirst();
      _visibilityChanges.addLast(now);
    }
    while (_visibilityChanges.isNotEmpty &&
        now - _visibilityChanges.first > 1600) {
      _visibilityChanges.removeFirst();
    }
    _lastPeople = count;
    final observed = _inspect(sample);
    if (_candidate != observed.issue) {
      _candidate = observed.issue;
      _candidateAt = now;
    }
    if (_candidate == FramingIssue.multiplePeople ||
        now - _candidateAt >= 240) {
      _issue = _candidate;
    }
    final rangeValid =
        minZoom.isFinite &&
        maxZoom.isFinite &&
        currentZoom.isFinite &&
        minZoom > 0 &&
        maxZoom >= minZoom &&
        currentZoom >= minZoom &&
        currentZoom <= maxZoom;
    var direction = _Adjustment.hold;
    final holdView =
        tracking == TrackingStatus.moving ||
        (recording && tracking == TrackingStatus.ready);
    if (rangeValid && !holdView) {
      if (observed.widen) {
        direction = _Adjustment.widen;
      } else if (!recording && observed.tightenBy > 1.04) {
        direction = _Adjustment.tighten;
      }
    }
    if (direction != _adjustment ||
        direction == _Adjustment.tighten && observed.movedFrom(_baseline)) {
      _adjustment = direction;
      _adjustmentAt = now;
      _baseline = observed;
    }
    final held = now - _adjustmentAt;
    if (_adjustment != _Adjustment.widen && held >= 1000) {
      _requestedWider = false;
    }
    if (_adjustment == _Adjustment.hold || now < _nextAdjustmentAt) return null;
    if (_adjustment == _Adjustment.widen) {
      if (held < 850) return null;
      if (currentZoom - minZoom > .01) {
        _nextAdjustmentAt = now + _adjustmentCooldownMs;
        return observed.issue == FramingIssue.searching
            ? minZoom
            : math.max(minZoom, currentZoom * .75);
      }
      if (held >= 1650 && !_requestedWider) {
        _needsWiderLens = _requestedWider = true;
        _nextAdjustmentAt = now + _adjustmentCooldownMs;
      }
      return null;
    }
    if (held < 1250) return null;
    final target = math.min(
      math.min(maxZoom, 1.8),
      currentZoom * observed.tightenBy,
    );
    if (target <= currentZoom * 1.04) return null;
    _nextAdjustmentAt = now + _adjustmentCooldownMs;
    return target;
  }

  _Observation _inspect(PoseSample sample) {
    if (sample.people.length > 1) {
      return const _Observation(FramingIssue.multiplePeople);
    }
    if (sample.people.isEmpty) {
      return const _Observation(FramingIssue.searching, widen: true);
    }
    final joints = sample.people.single;
    if (joints.length != 33) return const _Observation(FramingIssue.searching);
    final squat = exercise == Exercise.squat;
    final required = squat
        ? const [11, 23, 25, 27]
        : const [11, 13, 15, 23, 27];
    double score(int side) => required.fold(0.0, (sum, index) {
      final point = joints[index + side];
      return _onScreen(point) ? sum + 10 + point.visibility : sum;
    });
    final side = score(0) >= score(1) ? 0 : 1;
    final points = [
      for (final index in required)
        if (_onScreen(joints[index + side])) joints[index + side],
    ];
    if (points.isEmpty) {
      return _Observation(
        FramingIssue.searching,
        widen: joints.any(
          (p) => p.x.isFinite && p.y.isFinite && p.visibility.isFinite,
        ),
      );
    }
    final left = points.map((p) => p.x).reduce(math.min);
    final right = points.map((p) => p.x).reduce(math.max);
    final top = points.map((p) => p.y).reduce(math.min);
    final bottom = points.map((p) => p.y).reduce(math.max);
    final centerX = (left + right) / 2;
    final centerY = (top + bottom) / 2;
    final span = math.max(right - left, bottom - top);
    final offCenter = (centerX - .5).abs() > .23 || (centerY - .5).abs() > .26;
    final nearEdge = left < .045 || top < .045 || right > .955 || bottom > .955;
    final shoulder = joints[11 + side];
    final elbow = joints[13 + side];
    final wrist = joints[15 + side];
    final hip = joints[23 + side];
    final ankle = joints[27 + side];
    final hasTorso = _onScreen(shoulder) && _onScreen(hip);
    final legsMissing =
        !_onScreen(ankle) || squat && !_onScreen(joints[25 + side]);
    final armsMissing = !squat && (!_onScreen(elbow) || !_onScreen(wrist));
    final dx = (hip.x - shoulder.x) * sample.aspect;
    final dy = hip.y - shoulder.y;
    final alongExercise = squat ? dy > dx.abs() : dx.abs() > dy.abs();
    final legsAtEdge =
        hasTorso &&
        legsMissing &&
        alongExercise &&
        _endsAtEdge(shoulder, hip, 1.4);
    final handsAtEdge =
        armsMissing &&
        _onScreen(shoulder) &&
        _onScreen(elbow) &&
        _endsAtEdge(shoulder, elbow, .85);
    final otherShoulder = joints[12 - side];
    final fillsWidth =
        !hasTorso &&
        _onScreen(shoulder) &&
        _onScreen(otherShoulder) &&
        (shoulder.x - otherShoulder.x).abs() > .46;
    if (span > .89 ||
        legsAtEdge ||
        handsAtEdge ||
        fillsWidth ||
        nearEdge && !offCenter && span > .53) {
      return const _Observation(FramingIssue.tooClose, widen: true);
    }
    if (nearEdge && (offCenter || points.length < required.length)) {
      return _Observation(
        FramingIssue.offCenter,
        widen: span > .28 || points.length < required.length,
      );
    }
    if (!hasTorso ||
        math.max(dx.abs(), dy.abs()) < .016 * math.min(1, sample.aspect)) {
      return const _Observation(FramingIssue.missingTorso);
    }
    if (armsMissing) return const _Observation(FramingIssue.missingArms);
    if (legsMissing) return const _Observation(FramingIssue.missingLegs);
    if (offCenter) return const _Observation(FramingIssue.offCenter);
    if (span >= .33) return const _Observation(FramingIssue.clear);
    final knee = joints[25 + side];
    final extended = squat
        ? knee.y > hip.y && ankle.y > knee.y && ankle.y - hip.y >= dy * .9
        : (ankle.x - hip.x) * (hip.x - shoulder.x) > 0 &&
              (ankle.y - shoulder.y).abs() <
                  (ankle.x - shoulder.x).abs() * sample.aspect * .55;
    if (!alongExercise || !extended) {
      return const _Observation(FramingIssue.tooFar);
    }
    final radius = joints
        .where(_onScreen)
        .map((p) => math.max((p.x - .5).abs(), (p.y - .5).abs()))
        .reduce(math.max);
    return _Observation(
      FramingIssue.tooFar,
      centerX: centerX,
      centerY: centerY,
      span: span,
      tightenBy: math.min(1.35, math.min(.48 / span, .38 / radius)),
    );
  }

  static bool _onScreen(Joint point) =>
      point.x.isFinite &&
      point.y.isFinite &&
      point.visibility.isFinite &&
      point.visibility >= .65 &&
      point.visibility <= 1 &&
      point.x >= 0 &&
      point.x <= 1 &&
      point.y >= 0 &&
      point.y <= 1;

  static bool _endsAtEdge(Joint start, Joint end, double length) {
    final x = end.x + (end.x - start.x) * length;
    final y = end.y + (end.y - start.y) * length;
    return x < .045 || x > .955 || y < .045 || y > .955;
  }
}

final class _Observation {
  const _Observation(
    this.issue, {
    this.widen = false,
    this.centerX = .5,
    this.centerY = .5,
    this.span = 0,
    this.tightenBy = 1,
  });

  final FramingIssue issue;
  final bool widen;
  final double centerX, centerY, span, tightenBy;

  bool movedFrom(_Observation? baseline) =>
      baseline == null ||
      (centerX - baseline.centerX).abs() > .045 ||
      (centerY - baseline.centerY).abs() > .045 ||
      (span - baseline.span).abs() > math.max(.025, baseline.span * .18);
}
