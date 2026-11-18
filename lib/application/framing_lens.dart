import 'dart:async';

import 'package:camera/camera.dart';

CameraDescription defaultLens(
  List<CameraDescription> cameras,
  CameraLensDirection direction,
) {
  final matching = cameras.where((camera) => camera.lensDirection == direction);
  return matching
          .where((camera) => camera.lensType == CameraLensType.wide)
          .firstOrNull ??
      matching.firstOrNull ??
      cameras.first;
}

CameraDescription? widerLens(
  CameraDescription active,
  Iterable<CameraDescription> cameras,
  Map<String, double> viewWidths,
  double minZoom,
) {
  if (active.lensDirection == CameraLensDirection.external) return null;
  final candidates = cameras.where(
    (camera) =>
        camera.lensDirection == active.lensDirection &&
        camera.name != active.name,
  );
  final current = viewWidths[active.name];
  if (current != null && current.isFinite && current > 0) {
    var requiredWidth = current / minZoom * 1.18;
    CameraDescription? widest;
    for (final candidate in candidates) {
      final width = viewWidths[candidate.name];
      if (width != null && width.isFinite && width > requiredWidth) {
        widest = candidate;
        requiredWidth = width;
      }
    }
    if (widest != null) return widest;
  }
  if (minZoom < .99 || active.lensType == CameraLensType.ultraWide) return null;
  if (active.lensType == CameraLensType.wide ||
      active.lensType == CameraLensType.telephoto) {
    final ultra = candidates
        .where((camera) => camera.lensType == CameraLensType.ultraWide)
        .firstOrNull;
    if (ultra != null) return ultra;
  }
  return active.lensType == CameraLensType.telephoto
      ? candidates
            .where((camera) => camera.lensType == CameraLensType.wide)
            .firstOrNull
      : null;
}

final class FramingZoom {
  FramingZoom(this._min, this._max, this._write)
    : _current = 1.0.clamp(_min, _max);

  final double _min;
  final double _max;
  final Future<void> Function(double)? _write;
  double _current;
  bool _disabled = false;
  Future<void>? _pending;

  double get current => _current;
  double get minimum => _disabled ? current : _min;
  double get maximum => _disabled ? current : _max;
  bool get adjusting => _pending != null;
  Future<void> get idle => _pending ?? Future.value();

  static Future<FramingZoom> read(CameraController camera) async {
    try {
      final bounds = await Future.wait([
        camera.getMinZoomLevel(),
        camera.getMaxZoomLevel(),
      ]).timeout(const Duration(seconds: 2));
      final min = bounds.first, max = bounds.last;
      if (min.isFinite && max.isFinite && min > 0 && min <= max) {
        return FramingZoom(min, max, (level) async {
          await camera.setZoomLevel(level);
          if (camera.value.hasError) throw StateError('Camera rejected zoom');
        });
      }
    } on Object {
      return FramingZoom(1, 1, null);
    }
    return FramingZoom(1, 1, null);
  }

  Future<void> move(double level) {
    if (adjusting ||
        _write == null ||
        !level.isFinite ||
        level < minimum ||
        level > maximum ||
        level == current) {
      return idle;
    }
    return _pending = _apply(level).whenComplete(() {
      _pending = null;
    });
  }

  Future<void> _apply(double level) async {
    try {
      await _write!(level).timeout(const Duration(seconds: 2));
      _current = level;
    } on Object {
      _disabled = true;
    }
  }
}
