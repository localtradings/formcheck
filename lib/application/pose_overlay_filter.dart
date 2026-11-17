import 'dart:math' as math;

import '../domain/rep_analyzer.dart';

/// Display-only stabilization. Raw samples remain authoritative for rep checks.
/// No prediction or holding of absent landmarks; a weak observation expires.
final class PoseOverlayFilter {
  static const _acquire = .60;
  static const _release = .45;
  static const _weakWindowMs = 180;
  static const _gapMs = 250;
  final _joints = List<_FilteredJoint?>.filled(33, null);
  int? _lastTime;
  double? _aspect;
  (double, double)? _center;

  static bool canDraw(Joint p) =>
      p.visibility.isFinite &&
      p.visibility >= _release &&
      p.x.isFinite &&
      p.y.isFinite &&
      p.x >= 0 &&
      p.x <= 1 &&
      p.y >= 0 &&
      p.y <= 1;

  void reset() {
    _joints.fillRange(0, _joints.length, null);
    _lastTime = null;
    _aspect = null;
    _center = null;
  }

  List<List<Joint>> accept(PoseSample sample) {
    final time = sample.timestampMs;
    final previous = _lastTime;
    if (sample.people.length != 1 ||
        sample.people.single.length != 33 ||
        !sample.aspect.isFinite ||
        sample.aspect <= 0 ||
        (previous != null && time <= previous)) {
      reset();
      return const [];
    }
    final raw = sample.people.single;
    final anchors = [
      for (final i in [11, 12, 23, 24])
        if (canDraw(raw[i])) raw[i],
    ];
    final center = anchors.length < 2
        ? null
        : (
            anchors.map((p) => p.x * sample.aspect).reduce((a, b) => a + b) /
                anchors.length,
            anchors.map((p) => p.y).reduce((a, b) => a + b) / anchors.length,
          );
    final oldCenter = _center;
    final subjectChanged =
        center != null &&
        oldCenter != null &&
        math.sqrt(
              math.pow(center.$1 - oldCenter.$1, 2) +
                  math.pow(center.$2 - oldCenter.$2, 2),
            ) >
            .25;
    if ((previous != null && time - previous > _gapMs) ||
        _aspect != sample.aspect ||
        subjectChanged) {
      reset();
    }
    final dt = _lastTime == null ? 0.0 : (time - _lastTime!) / 1000;
    _lastTime = time;
    _aspect = sample.aspect;
    _center = center;
    return [
      [
        for (var i = 0; i < 33; i++)
          _acceptJoint(i, raw[i], time, dt, sample.aspect),
      ],
    ];
  }

  Joint _acceptJoint(int index, Joint raw, int time, double dt, double aspect) {
    final state = _joints[index];
    if (!canDraw(raw) ||
        (raw.visibility < _acquire &&
            (state == null || time - state.strongAt > _weakWindowMs))) {
      _joints[index] = null;
      return const Joint(0, 0, 0);
    }
    if (state == null || dt == 0) {
      _joints[index] = _FilteredJoint(raw.x * aspect, raw.y, time);
      return raw;
    }
    if (raw.visibility >= _acquire) state.strongAt = time;
    final x = raw.x * aspect;
    final y = raw.y;
    // One Euro style adaptive cutoff: damp small jitter and follow fast motion.
    final derivativeAlpha = _alpha(1, dt);
    state.dx += derivativeAlpha * ((x - state.rawX) / dt - state.dx);
    state.dy += derivativeAlpha * ((y - state.rawY) / dt - state.dy);
    final speed = math.sqrt(state.dx * state.dx + state.dy * state.dy);
    final alpha = _alpha(1.7 + 12 * speed, dt);
    state.x += alpha * (x - state.x);
    state.y += alpha * (y - state.y);
    // Bound visual lag to 1.2% of image height, including during fast reversals.
    final deltaX = state.x - x;
    final deltaY = state.y - y;
    final distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);
    if (distance > .012) {
      state.x = x + deltaX * .012 / distance;
      state.y = y + deltaY * .012 / distance;
    }
    state.rawX = x;
    state.rawY = y;
    return Joint(state.x / aspect, state.y, raw.visibility);
  }

  static double _alpha(double cutoff, double dt) =>
      1 / (1 + 1 / (2 * math.pi * cutoff * dt));
}

final class _FilteredJoint {
  _FilteredJoint(this.x, this.y, this.strongAt) : rawX = x, rawY = y;
  double x, y, rawX, rawY;
  double dx = 0, dy = 0;
  int strongAt;
}
