import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../domain/rep_analyzer.dart';

/// Geometry belongs to the submitted frame, not a later camera orientation.
final class PoseFrameGeometry {
  const PoseFrameGeometry({
    required this.width,
    required this.height,
    required this.rotation,
    required this.mirror,
  });

  factory PoseFrameGeometry.camera({
    required int width,
    required int height,
    required int sensorOrientation,
    required CameraLensDirection lens,
    required DeviceOrientation orientation,
    required TargetPlatform platform,
  }) {
    final front = lens == CameraLensDirection.front;
    final portrait =
        orientation == DeviceOrientation.portraitUp ||
        orientation == DeviceOrientation.portraitDown;
    final deviceRotation = switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    // AVFoundation rotates its image stream and texture together. Android
    // delivers sensor buffers and mirrors only its front-camera texture.
    final rotation = platform == TargetPlatform.iOS
        ? (portrait && width > height ? sensorOrientation : 0)
        : (sensorOrientation +
                  (front ? deviceRotation : -deviceRotation) +
                  360) %
              360;
    return PoseFrameGeometry(
      width: width,
      height: height,
      rotation: rotation,
      // Match the familiar front-camera display on Android. iOS pixels
      // already contain the front-camera reflection.
      mirror: platform == TargetPlatform.android && front,
    );
  }

  final int width;
  final int height;
  final int rotation;
  final bool mirror;

  ui.Size get uprightSize => (rotation ~/ 90).isOdd
      ? ui.Size(height.toDouble(), width.toDouble())
      : ui.Size(width.toDouble(), height.toDouble());
  double get aspect => uprightSize.width / uprightSize.height;

  Joint upright(Joint joint) {
    final (x, y) = switch (rotation) {
      90 => (1 - joint.y, joint.x),
      180 => (1 - joint.x, 1 - joint.y),
      270 => (joint.y, 1 - joint.x),
      _ => (joint.x, joint.y),
    };
    return Joint(x, y, joint.visibility);
  }

  ui.Offset project(Joint joint, ui.Size viewSize) {
    final point = upright(joint);
    final size = uprightSize;
    final scale = math.min(
      viewSize.width / size.width,
      viewSize.height / size.height,
    );
    return ui.Offset(
      (viewSize.width - size.width * scale) / 2 +
          (mirror ? 1 - point.x : point.x) * size.width * scale,
      (viewSize.height - size.height * scale) / 2 +
          point.y * size.height * scale,
    );
  }

  /// Applies the identical transform used by [project] to the sensor pixels.
  void paintImage(ui.Canvas canvas, ui.Size viewSize, ui.Image image) {
    final size = uprightSize;
    final scale = math.min(
      viewSize.width / size.width,
      viewSize.height / size.height,
    );
    canvas.save();
    canvas.translate(
      (viewSize.width - size.width * scale) / 2,
      (viewSize.height - size.height * scale) / 2,
    );
    canvas.scale(scale);
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    switch (rotation) {
      case 90:
        canvas.translate(height.toDouble(), 0);
        canvas.rotate(math.pi / 2);
      case 180:
        canvas.translate(width.toDouble(), height.toDouble());
        canvas.rotate(math.pi);
      case 270:
        canvas.translate(0, width.toDouble());
        canvas.rotate(-math.pi / 2);
    }
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    canvas.restore();
  }

  @override
  bool operator ==(Object other) =>
      other is PoseFrameGeometry &&
      other.width == width &&
      other.height == height &&
      other.rotation == rotation &&
      other.mirror == mirror;

  @override
  int get hashCode => Object.hash(width, height, rotation, mirror);
}

/// Pixels and display landmarks from one inference are published together.
/// Display stabilization must not be used as input to the rep analyzer.
final class PoseFrame {
  const PoseFrame(this.image, this.geometry, this.people, this.timestampMs);
  final ui.Image image;
  final PoseFrameGeometry geometry;
  final List<List<Joint>> people;
  final int timestampMs;
}

/// Decode the very same owned pixels sent to the native pose task.
Future<ui.Image> decodePoseFrame(VisionImage image) {
  final result = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    image.pixels!,
    image.width!,
    image.height!,
    image.format == VisionPixelFormat.bgra
        ? ui.PixelFormat.bgra8888
        : ui.PixelFormat.rgba8888,
    result.complete,
    rowBytes: image.bytesPerRow,
  );
  return result.future;
}
