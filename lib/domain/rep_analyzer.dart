import 'dart:math' as math;

import 'workout.dart';

final class Joint {
  const Joint(this.x, this.y, this.visibility);
  final double x;
  final double y;
  final double visibility;
  bool get visible =>
      visibility >= 0.65 && x >= 0.02 && x <= 0.98 && y >= 0.02 && y <= 0.98;
}

final class PoseSample {
  const PoseSample(this.timestampMs, this.aspect, this.people);
  final int timestampMs;
  final double aspect;
  final List<List<Joint>> people;
}

typedef Analysis = ({TrackingStatus status, RepResult? rep, Cue? cue});

final class FormProfile {
  const FormProfile._(this.id, this.top, this.motion, this.depth);
  static const squat = FormProfile._('side-squat-v1', 153, 128, 105);
  static const pushUp = FormProfile._('side-push-up-v1', 151, 127, 100);
  static FormProfile forExercise(Exercise exercise) => switch (exercise) {
    Exercise.squat => squat,
    Exercise.pushUp => pushUp,
    _ => throw ArgumentError.value(exercise, 'exercise'),
  };

  final String id;
  final double top;
  final double motion;
  final double depth;
}

final class RepAnalyzer {
  RepAnalyzer(this.exercise) : profile = FormProfile.forExercise(exercise);
  final Exercise exercise;
  final FormProfile profile;

  static const readyMs = 400;
  static const maxFrameGapMs = 350;
  static const minRepMs = 300;
  static const maxRepMs = 12000;
  static const completionHoldMs = 120;

  int? _lastTime;
  int? _side;
  int? _topSince;
  int? _startedAt;
  int? _returnSince;
  double? _filteredAngle;
  double _deepest = 180;
  double _lineEvidenceMs = 0;
  double _lineDriftMs = 0;
  double _activeMs = 0;
  int? _lastCueAt;
  bool _armed = false;

  void reset() {
    _lastTime = null;
    _side = null;
    _topSince = null;
    _filteredAngle = null;
    _armed = false;
    _clearMovement();
  }

  Analysis accept(PoseSample sample) {
    final now = sample.timestampMs;
    final previous = _lastTime;
    if (previous != null && now <= previous) {
      return (status: TrackingStatus.getReady, rep: null, cue: null);
    }
    if (previous != null && now - previous > maxFrameGapMs) reset();
    final dt = _lastTime == null ? 0 : now - _lastTime!;
    _lastTime = now;
    if (sample.people.length != 1 ||
        sample.people.single.length < 33 ||
        !sample.aspect.isFinite ||
        sample.aspect <= 0) {
      return _lost();
    }
    final joints = sample.people.single;
    final side = _side ?? _selectSide(joints);
    if (side == null ||
        !_primaryJoints(side).every((index) => joints[index].visible) ||
        !_sideOn(joints, side, sample.aspect)) {
      return _lost();
    }

    final ids = _primaryJoints(side);
    final angle = _angle(
      joints[ids[0]],
      joints[ids[1]],
      joints[ids[2]],
      sample.aspect,
    );
    if (angle == null) return _lost();
    _side = side;
    final oldAngle = _filteredAngle;
    // Use a time-based filter so behavior remains comparable across frame rates.
    final alpha = 1 - math.exp(-dt / 75);
    final filtered = oldAngle == null
        ? angle
        : oldAngle + alpha * (angle - oldAngle);
    _filteredAngle = filtered;

    if (!_armed) {
      if (filtered >= profile.top && _validTop(joints, side, sample.aspect)) {
        _topSince ??= now;
        _armed = now - _topSince! >= readyMs;
      } else {
        _topSince = null;
      }
      return (
        status: _armed ? TrackingStatus.ready : TrackingStatus.getReady,
        rep: null,
        cue: null,
      );
    }

    if (_startedAt == null) {
      if (filtered > profile.motion) {
        return (status: TrackingStatus.ready, rep: null, cue: null);
      }
      _startedAt = now;
    }
    final elapsed = now - _startedAt!;
    if (elapsed > maxRepMs) return _lost();
    _deepest = math.min(_deepest, filtered);
    _returnSince = filtered >= profile.top ? _returnSince ?? now : null;

    Cue? liveCue;
    if (exercise == Exercise.pushUp && filtered < profile.top) {
      _activeMs += dt;
      final line = _line(joints, side, sample.aspect);
      if (line != null) {
        _lineEvidenceMs += dt;
        if (line < 155) {
          _lineDriftMs += dt;
          if (_lineDriftMs >= 200) liveCue = _cue(Cue.bodyLine, now);
        }
      }
    }
    if (_returnSince == null || now - _returnSince! < completionHoldMs) {
      return (status: TrackingStatus.moving, rep: null, cue: liveCue);
    }
    if (elapsed < minRepMs) {
      _clearMovement();
      return (status: TrackingStatus.ready, rep: null, cue: null);
    }
    final result = _classify();
    _clearMovement();
    return (
      status: TrackingStatus.ready,
      rep: result,
      cue: result.cue == null ? null : _cue(result.cue!, now),
    );
  }

  RepResult _classify() {
    if (exercise == Exercise.pushUp &&
        (_activeMs <= 0 || _lineEvidenceMs / _activeMs < 0.75)) {
      return const RepResult(RepOutcome.unassessed, Cue.reframe);
    }
    if (exercise == Exercise.pushUp && _lineDriftMs >= 200) {
      return const RepResult(RepOutcome.needsCorrection, Cue.bodyLine);
    }
    if (_deepest > profile.depth) {
      return RepResult(
        RepOutcome.needsCorrection,
        exercise == Exercise.squat ? Cue.squatDepth : Cue.pushUpDepth,
      );
    }
    return const RepResult(RepOutcome.passed);
  }

  Analysis _lost() {
    reset();
    return (status: TrackingStatus.reposition, rep: null, cue: null);
  }

  void _clearMovement() {
    _startedAt = null;
    _returnSince = null;
    _deepest = 180;
    _lineEvidenceMs = 0;
    _lineDriftMs = 0;
    _activeMs = 0;
  }

  Cue? _cue(Cue value, int now) {
    final last = _lastCueAt;
    if (last != null && now - last < 2400) return null;
    _lastCueAt = now;
    return value;
  }

  List<int> _primaryJoints(int side) => exercise == Exercise.squat
      ? [23 + side, 25 + side, 27 + side]
      : [11 + side, 13 + side, 15 + side];

  int? _selectSide(List<Joint> joints) {
    double score(int side) {
      final values = _primaryJoints(side).map((i) => joints[i]);
      return values.every((j) => j.visible)
          ? values.map((j) => j.visibility).reduce(math.min)
          : -1;
    }

    final left = score(0);
    final right = score(1);
    if (left < 0 && right < 0) return null;
    return left >= right ? 0 : 1;
  }

  bool _sideOn(List<Joint> joints, int side, double aspect) {
    final shoulder = joints[11 + side];
    final hip = joints[23 + side];
    if (!shoulder.visible || !hip.visible) {
      // A missing push-up hip reduces alignment coverage independently of elbow tracking.
      return exercise == Exercise.pushUp && _armed;
    }
    final farShoulder = joints[12 - side];
    final farHip = joints[24 - side];
    final torso = _distance(shoulder, hip, aspect);
    if (torso < 0.055) return false;
    if (farShoulder.visible &&
        _distance(shoulder, farShoulder, aspect) > torso * 0.64) {
      return false;
    }
    return !farHip.visible || _distance(hip, farHip, aspect) <= torso * 0.58;
  }

  bool _validTop(List<Joint> joints, int side, double aspect) {
    final shoulder = joints[11 + side];
    final hip = joints[23 + side];
    final ankle = joints[27 + side];
    if (![shoulder, hip, ankle].every((point) => point.visible)) return false;
    if (exercise == Exercise.pushUp) {
      final horizontal = (shoulder.x - ankle.x).abs() * aspect;
      return horizontal > 0.15 &&
          (shoulder.y - ankle.y).abs() < horizontal * 0.48 &&
          (_line(joints, side, aspect) ?? 0) >= 155;
    }
    final knee = joints[25 + side];
    return shoulder.y < hip.y && hip.y < knee.y && knee.y < ankle.y;
  }

  double? _line(List<Joint> joints, int side, double aspect) {
    final a = joints[11 + side], b = joints[23 + side], c = joints[27 + side];
    return a.visible && b.visible && c.visible ? _angle(a, b, c, aspect) : null;
  }

  static double _distance(Joint a, Joint b, double aspect) =>
      math.sqrt(math.pow((a.x - b.x) * aspect, 2) + math.pow(a.y - b.y, 2));

  static double? _angle(Joint a, Joint b, Joint c, double aspect) {
    final ax = (a.x - b.x) * aspect, ay = a.y - b.y;
    final cx = (c.x - b.x) * aspect, cy = c.y - b.y;
    final denominator = _distance(a, b, aspect) * _distance(c, b, aspect);
    if (denominator <= 0.00001) return null;
    final cosine = ((ax * cx + ay * cy) / denominator).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }
}
