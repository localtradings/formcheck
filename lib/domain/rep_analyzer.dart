import 'dart:collection';
import 'dart:math' as math;

import 'workout.dart';

final class Joint {
  const Joint(this.x, this.y, this.visibility);
  final double x;
  final double y;
  final double visibility;
  bool get visible =>
      visibility.isFinite &&
      visibility >= 0.65 &&
      visibility <= 1 &&
      x >= 0.02 &&
      x <= 0.98 &&
      y >= 0.02 &&
      y <= 0.98;
}

final class PoseSample {
  const PoseSample(this.timestampMs, this.aspect, this.people);
  final int timestampMs;
  final double aspect;
  final List<List<Joint>> people;
}

typedef Analysis = ({TrackingStatus status, RepResult? rep, Cue? cue});
typedef _SideView = ({
  int side,
  double angle,
  double confidence,
  double length,
  bool atTop,
});

final class FormProfile {
  const FormProfile._(this.id, this.top, this.motion, this.depth);
  static const squat = FormProfile._('side-squat-v5', 153, 128, 105);
  static const pushUp = FormProfile._('side-push-up-v5', 151, 127, 100);
  static const depthMarginDegrees = 4.0;
  static const bodyLineDegrees = 155.0;
  static const bodyLineMarginDegrees = 4.0;
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
  static const _maxEvidenceGapMs = 200;
  static const _sideConflictMs = 200;
  static const _approachTravel = .025;

  int? _lastTime;
  int? _side;
  ({Joint shoulder, Joint hip, Joint contact, double aspect})? _lastBody;
  ({double bodyY, Joint support, double length, double highestAngle})?
  _startPose;
  int? _topSince;
  int? _sideConflictSince;
  int? _startedAt;
  int? _returnSince;
  int? _invalidEndSince;
  double? _filteredAngle;
  final _depth = _DepthEvidence();
  double _maxDrop = 0;
  int _lineEvidenceMs = 0;
  int _lineDriftMs = 0;
  int _possibleDriftMs = 0;
  int _activeMs = 0;
  double? _previousLine;
  bool _alignmentFault = false;
  bool _alignmentUncertain = false;
  int? _lastCueAt;
  bool _armed = false;

  double? get jointAngleDegrees => _filteredAngle;
  int? get measuredSide => _side;

  void reset() {
    _lastTime = null;
    _lastCueAt = null;
    _clearTracking();
  }

  void _clearTracking() {
    _side = null;
    _lastBody = null;
    _startPose = null;
    _topSince = null;
    _sideConflictSince = null;
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
        sample.people.single.length != 33 ||
        !sample.aspect.isFinite ||
        sample.aspect <= 0) {
      return _lost();
    }
    final joints = sample.people.single;
    final view = _selectView(joints, sample.aspect, now);
    if (view == null) return _lost();
    final side = view.side;
    if (_side != null && side != _side) _clearTracking();
    if (_bodyJumped(joints, side, sample.aspect, dt)) return _lost();
    _side = side;
    final oldAngle = _filteredAngle;
    // Use a time-based filter so behavior remains comparable across frame rates.
    final alpha = 1 - math.exp(-dt / 75);
    final filtered = oldAngle == null
        ? view.angle
        : oldAngle + alpha * (view.angle - oldAngle);
    _filteredAngle = filtered;

    final first = (exercise == Exercise.squat ? 23 : 11) + side;
    final body = joints[first], support = joints[first + 4];
    final extended = filtered >= profile.top && view.angle >= profile.top;
    final atTop = extended && view.atTop;
    if (!_armed) {
      if (atTop) {
        _topSince ??= now;
        _armed = now - _topSince! >= readyMs;
      } else {
        _topSince = null;
      }
      if (!_armed) {
        return (status: TrackingStatus.getReady, rep: null, cue: null);
      }
    }
    if (_startedAt == null && atTop) {
      final highest = _startPose?.highestAngle ?? view.angle;
      if (view.angle >= highest - 2) {
        _startPose = (
          bodyY: body.y,
          support: support,
          length: view.length,
          highestAngle: math.max(highest, view.angle),
        );
      }
      return (status: TrackingStatus.ready, rep: null, cue: null);
    }
    final start = _startPose!;
    if (_distance(start.support, support, sample.aspect) > .30 * start.length) {
      return _lost();
    }
    final (bodyDrop, relativeDrop) = _travel(body, support);
    final drop = math.min(bodyDrop, relativeDrop);
    final bent = view.angle <= profile.motion && drop >= .06;
    if (_startedAt == null) {
      if (view.angle >= profile.top || drop < _approachTravel) {
        if (!extended) {
          return (status: TrackingStatus.moving, rep: null, cue: null);
        }
        _clearTracking();
        return (status: TrackingStatus.getReady, rep: null, cue: null);
      }
      _startedAt = now;
    }
    final elapsed = now - _startedAt!;
    if (elapsed > maxRepMs) return _lost();
    _maxDrop = math.max(_maxDrop, drop);
    _depth.observe(now, dt, bent ? view.angle : null);
    final nearStart =
        math.max(bodyDrop, relativeDrop) <= math.min(.13, .45 * _maxDrop);
    final missingLine =
        exercise == Exercise.pushUp &&
        (!joints[23 + side].visible || !joints[27 + side].visible);
    final atEnd =
        extended &&
        nearStart &&
        (view.atTop ||
            (missingLine && _hasSupportBelow(body, support, view.length)));
    _returnSince = atEnd ? _returnSince ?? now : null;
    _invalidEndSince = extended && !atEnd ? _invalidEndSince ?? now : null;
    if (_invalidEndSince != null && now - _invalidEndSince! >= readyMs) {
      return _lost();
    }
    final liveCue = exercise == Exercise.pushUp
        ? _observeAlignment(
            joints,
            side,
            sample.aspect,
            now,
            elapsed == 0 ? 0 : dt,
            extended,
          )
        : null;
    if (_returnSince == null || now - _returnSince! < completionHoldMs) {
      return (status: TrackingStatus.moving, rep: null, cue: liveCue);
    }
    final supportedBottom = _depth.supported;
    final result = elapsed >= minRepMs && supportedBottom != null
        ? _classify(missingLine, supportedBottom)
        : null;
    if (missingLine) {
      _clearTracking();
    } else {
      _clearMovement();
      _startPose = (
        bodyY: body.y,
        support: support,
        length: view.length,
        highestAngle: view.angle,
      );
    }
    return (
      status: missingLine ? TrackingStatus.getReady : TrackingStatus.ready,
      rep: result,
      cue: result?.cue == null ? null : _cue(result!.cue!, now),
    );
  }

  Cue? _observeAlignment(
    List<Joint> joints,
    int side,
    double aspect,
    int now,
    int dt,
    bool extended,
  ) {
    if (extended) {
      _previousLine = null;
      _lineDriftMs = 0;
      _possibleDriftMs = 0;
      return null;
    }
    final line = _line(joints, side, aspect);
    final previous = _previousLine;
    _previousLine = line;
    _activeMs += dt;
    if (previous == null || line == null || dt > _maxEvidenceGapMs) {
      _lineDriftMs = 0;
      _possibleDriftMs = 0;
      return null;
    }
    _lineEvidenceMs += dt;
    final upperAngle = math.max(previous, line);
    _lineDriftMs =
        upperAngle <
            FormProfile.bodyLineDegrees - FormProfile.bodyLineMarginDegrees
        ? _lineDriftMs + dt
        : 0;
    _possibleDriftMs =
        upperAngle <
            FormProfile.bodyLineDegrees + FormProfile.bodyLineMarginDegrees
        ? _possibleDriftMs + dt
        : 0;
    if (_possibleDriftMs >= 200) _alignmentUncertain = true;
    if (_lineDriftMs < 200) return null;
    _alignmentFault = true;
    return _cue(Cue.bodyLine, now);
  }

  RepResult _classify(bool missingLine, double supported) {
    final depthPass =
        supported <= profile.depth - FormProfile.depthMarginDegrees;
    final uncertainCapture =
        !depthPass &&
        (_depth.gap ||
            supported - _depth.lowestRaw > 2 * FormProfile.depthMarginDegrees);
    final angle = uncertainCapture ? null : supported.round();
    if (exercise == Exercise.pushUp &&
        (missingLine || _activeMs <= 0 || _lineEvidenceMs / _activeMs < 0.75)) {
      return RepResult(RepOutcome.unassessed, Cue.reframe, angle);
    }
    if (_alignmentFault) {
      return RepResult(RepOutcome.needsCorrection, Cue.bodyLine, angle);
    }
    if (!depthPass &&
        !uncertainCapture &&
        _depth.lowestRaw >= profile.depth + FormProfile.depthMarginDegrees) {
      return RepResult(
        RepOutcome.needsCorrection,
        exercise == Exercise.squat ? Cue.squatDepth : Cue.pushUpDepth,
        angle,
      );
    }
    if (_alignmentUncertain) {
      return RepResult(RepOutcome.unassessed, Cue.alignmentUnclear, angle);
    }
    if (depthPass) return RepResult(RepOutcome.passed, null, angle);
    return RepResult(RepOutcome.unassessed, Cue.depthUnclear, angle);
  }

  Analysis _lost() {
    _clearTracking();
    return (status: TrackingStatus.reposition, rep: null, cue: null);
  }

  void _clearMovement() {
    _startedAt = null;
    _returnSince = null;
    _invalidEndSince = null;
    _maxDrop = 0;
    _depth.clear();
    _lineEvidenceMs = 0;
    _lineDriftMs = 0;
    _possibleDriftMs = 0;
    _activeMs = 0;
    _previousLine = null;
    _alignmentFault = false;
    _alignmentUncertain = false;
  }

  Cue? _cue(Cue value, int now) {
    final last = _lastCueAt;
    if (last != null && now - last < 2400) return null;
    _lastCueAt = now;
    return value;
  }

  (double, double) _travel(Joint body, Joint support) {
    final start = _startPose!;
    final absolute = (body.y - start.bodyY) / start.length;
    return (absolute, absolute - (support.y - start.support.y) / start.length);
  }

  _SideView? _selectView(List<Joint> joints, double aspect, int now) {
    final first = _side ?? 0;
    final current = _readSide(joints, first, aspect);
    if (_startedAt != null) return current;
    final other = _readSide(joints, 1 - first, aspect);
    if (_armed && current != null && current.angle < profile.top) {
      final proximal = (exercise == Exercise.squat ? 23 : 11) + first;
      final (absolute, relative) = _travel(
        joints[proximal],
        joints[proximal + 4],
      );
      if (other?.atTop != true ||
          math.min(absolute, relative) >= _approachTravel) {
        _sideConflictSince = null;
        return current;
      }
      _sideConflictSince ??= now;
      if (now - _sideConflictSince! < _sideConflictMs) return current;
    } else {
      _sideConflictSince = null;
    }
    if (current == null) return other;
    if (other == null) return current;
    if (current.atTop != other.atTop) return current.atTop ? current : other;
    final switchMargin = _side == null ? 0.0 : .10;
    return other.confidence > current.confidence + switchMargin
        ? other
        : current;
  }

  _SideView? _readSide(List<Joint> joints, int side, double aspect) {
    final first = (exercise == Exercise.squat ? 23 : 11) + side;
    final proximal = joints[first];
    final middle = joints[first + 2];
    final distal = joints[first + 4];
    if (!proximal.visible ||
        !middle.visible ||
        !distal.visible ||
        !_sideOn(joints, side, aspect)) {
      return null;
    }
    final angle = _angle(proximal, middle, distal, aspect);
    if (angle == null) return null;
    final length =
        _distance(proximal, middle, aspect) + _distance(middle, distal, aspect);
    final supportConfidence = exercise == Exercise.squat
        ? joints[11 + side].visibility
        : math.min(joints[23 + side].visibility, joints[27 + side].visibility);
    return (
      side: side,
      angle: angle,
      length: length,
      confidence: math.min(
        math.min(proximal.visibility, middle.visibility),
        math.min(distal.visibility, supportConfidence),
      ),
      atTop:
          angle >= profile.top &&
          _hasSupportBelow(proximal, distal, length) &&
          _validTop(joints, side, aspect),
    );
  }

  bool _bodyJumped(List<Joint> joints, int side, double aspect, int dt) {
    final previous = _lastBody;
    final shoulder = joints[11 + side];
    final hip = joints[23 + side];
    final contact = joints[(exercise == Exercise.squat ? 27 : 15) + side];
    _lastBody = (
      shoulder: shoulder,
      hip: hip,
      contact: contact,
      aspect: aspect,
    );
    if (previous == null) return false;
    if (aspect != previous.aspect) return true;
    final dx = (contact.x - previous.contact.x) * aspect;
    final dy = contact.y - previous.contact.y;
    final travel = math.sqrt(dx * dx + dy * dy);
    final jumpDistance = math.min(1.0, aspect) * (.18 + .35 * dt / 1000);
    if (travel <= jumpDistance) return false;

    double alongTravel(Joint current, Joint last) =>
        ((current.x - last.x) * aspect * dx + (current.y - last.y) * dy) /
        travel;
    final shoulderShift = alongTravel(shoulder, previous.shoulder);
    final torsoShift = hip.visible && previous.hip.visible
        ? (shoulderShift + alongTravel(hip, previous.hip)) / 2
        : shoulderShift;
    return torsoShift > jumpDistance;
  }

  bool _sideOn(List<Joint> joints, int side, double aspect) {
    final shoulder = joints[11 + side];
    final hip = joints[23 + side];
    if (!shoulder.visible || !hip.visible) {
      // A missing push-up hip reduces alignment coverage independently of elbow tracking.
      return exercise == Exercise.pushUp && _armed && side == _side;
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
      final knee = joints[25 + side];
      final legAngle = knee.visible ? _angle(hip, knee, ankle, aspect) : null;
      return horizontal > 0.15 &&
          (shoulder.y - ankle.y).abs() < horizontal * 0.48 &&
          (legAngle == null || legAngle >= 130) &&
          (_line(joints, side, aspect) ?? 0) >= FormProfile.bodyLineDegrees;
    }
    final knee = joints[25 + side];
    return shoulder.y < hip.y && hip.y < knee.y && knee.y < ankle.y;
  }

  bool _hasSupportBelow(Joint body, Joint support, double length) =>
      support.y - body.y >= length * (exercise == Exercise.squat ? .65 : .55);

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

final class _DepthEvidence {
  static const spanMs = 65;
  final _samples = ListQueue<({int time, double angle})>();
  bool gap = false;
  double lowestRaw = 180;
  double? supported;

  void clear() {
    _samples.clear();
    gap = false;
    lowestRaw = 180;
    supported = null;
  }

  void observe(int now, int dt, double? angle) {
    if (dt > RepAnalyzer._maxEvidenceGapMs &&
        (_samples.isNotEmpty || angle != null)) {
      gap = true;
      _samples.clear();
    }
    if (angle == null) {
      _samples.clear();
      return;
    }
    lowestRaw = math.min(lowestRaw, angle);
    _samples.addLast((time: now, angle: angle));
    while (_samples.length > 1 && now - _samples.elementAt(1).time >= spanMs) {
      _samples.removeFirst();
    }
    if (now - _samples.first.time < spanMs) return;
    final windowAngle = _samples.fold(
      0.0,
      (largest, sample) => math.max(largest, sample.angle),
    );
    supported = math.min(supported ?? 180, windowAngle);
  }
}
