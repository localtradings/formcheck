import 'dart:math' as math;

/// Angle between the lens axis and a horizontal line, measured at the phone.
/// A moving reading has no usable angle for the current camera frame.
final class PhoneLevel {
  const PhoneLevel(
    this.pitchDegrees, {
    this.tilted = false,
    this.rolled = false,
  });
  const PhoneLevel.moving() : this(null);

  final double? pitchDegrees;
  final bool tilted;
  final bool rolled;
  bool get blocksAssessment => pitchDegrees == null || tilted || rolled;
}

final class PhoneLevelFilter {
  static const _freshMs = 550;
  static const _gravity = 9.80665;
  int? _last;
  int _since = 0;
  int _samples = 0;
  (double, double, double)? _anchor;
  double _pitch = 0, _roll = 0;
  bool _tilted = false, _rolled = false;
  PhoneLevel? _reading;

  void reset() {
    _last = null;
    _anchor = null;
    _reading = null;
    _tilted = _rolled = false;
  }

  PhoneLevel? at(int frameMs) {
    final last = _last;
    if (last == null || frameMs < last || frameMs - last > _freshMs) {
      return null;
    }
    return _reading;
  }

  /// Acceleration including gravity, in m/s² and device coordinates.
  void add(int ms, double x, double y, double z) {
    final previous = _last;
    if (previous != null && ms <= previous) return;
    if (previous != null && ms - previous > _freshMs) reset();
    _last = ms;
    final length = math.sqrt(x * x + y * y + z * z);
    if (!length.isFinite || (length - _gravity).abs() > 1.6) {
      _anchor = null;
      _reading = const PhoneLevel.moving();
      return;
    }
    x /= length;
    y /= length;
    z /= length;
    final horizontal = math.sqrt(x * x + y * y);
    final pitch = math.atan2(z.abs(), horizontal) * 180 / math.pi;
    // Distance to the nearest upright portrait or landscape orientation.
    final roll =
        math.atan2(math.min(x.abs(), y.abs()), math.max(x.abs(), y.abs())) *
        180 /
        math.pi;
    final anchor = _anchor;
    // Five degrees between directions is enough to restart the settling window.
    if (anchor == null ||
        x * anchor.$1 + y * anchor.$2 + z * anchor.$3 < .9962) {
      _anchor = (x, y, z);
      _since = ms;
      _samples = 1;
      _pitch = pitch;
      _roll = roll;
      _reading = const PhoneLevel.moving();
      return;
    }
    _samples++;
    final alpha = 1 - math.exp(-(ms - (previous ?? ms)) / 120);
    _pitch += alpha * (pitch - _pitch);
    _roll += alpha * (roll - _roll);
    if (_samples < 3 || ms - _since < 200) return;
    _tilted = _pitch > (_tilted ? 12 : 18);
    _rolled = _pitch < 70 && _roll > (_rolled ? 12 : 18);
    _reading = PhoneLevel(_pitch, tilted: _tilted, rolled: _rolled);
  }
}
