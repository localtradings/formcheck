// Adapted from Google flutter-mediapipe gallery/lib/live/camera_frame.dart.
// Apache-2.0. See plan.md for upstream provenance.
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// Copies camera pixels without rotating or resizing the sensor image.
VisionImage visionImageFromCamera(CameraImage image) {
  if (image.format.group == ImageFormatGroup.bgra8888 &&
      image.planes.length == 1) {
    final plane = image.planes.single;
    return VisionImage.fromPixels(
      pixels: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      format: image.format.raw == 'RGBA'
          ? VisionPixelFormat.rgba
          : VisionPixelFormat.bgra,
    );
  }
  if (image.format.group == ImageFormatGroup.yuv420 &&
      image.planes.length == 3) {
    final planes = image.planes;
    return VisionImage.fromPixels(
      pixels: yuv420ToRgba(
        width: image.width,
        height: image.height,
        y: planes[0].bytes,
        u: planes[1].bytes,
        v: planes[2].bytes,
        yRowStride: planes[0].bytesPerRow,
        uvRowStride: planes[1].bytesPerRow,
        vRowStride: planes[2].bytesPerRow,
        yPixelStride: planes[0].bytesPerPixel ?? 1,
        uvPixelStride: planes[1].bytesPerPixel ?? 1,
        vPixelStride: planes[2].bytesPerPixel ?? 1,
      ),
      width: image.width,
      height: image.height,
      format: VisionPixelFormat.rgba,
    );
  }
  throw StateError('Unsupported camera format: ${image.format.group}');
}

/// Android YUV_420_888 planes may be planar or interleaved and row-padded.
/// Each plane has its own stride; the final row need not include trailing padding.
Uint8List yuv420ToRgba({
  required int width,
  required int height,
  required Uint8List y,
  required Uint8List u,
  required Uint8List v,
  required int yRowStride,
  required int uvRowStride,
  required int vRowStride,
  int yPixelStride = 1,
  int uvPixelStride = 1,
  int vPixelStride = 1,
}) {
  void validate(Uint8List plane, int cols, int rows, int row, int pixel) {
    if (cols <= 0 ||
        rows <= 0 ||
        pixel <= 0 ||
        row < (cols - 1) * pixel + 1 ||
        plane.length < (rows - 1) * row + (cols - 1) * pixel + 1) {
      throw ArgumentError('Invalid YUV plane dimensions or strides');
    }
  }

  validate(y, width, height, yRowStride, yPixelStride);
  validate(u, (width + 1) ~/ 2, (height + 1) ~/ 2, uvRowStride, uvPixelStride);
  validate(v, (width + 1) ~/ 2, (height + 1) ~/ 2, vRowStride, vPixelStride);
  final rgba = Uint8List(width * height * 4);
  // dart2js bitwise shifts can treat negative intermediates as unsigned.
  // Floor division matches the VM's arithmetic right shift on every platform.
  int byte(int numerator) => (numerator / 256).floor().clamp(0, 255);
  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      final luma = y[row * yRowStride + col * yPixelStride] - 16;
      final cb = u[(row ~/ 2) * uvRowStride + (col ~/ 2) * uvPixelStride] - 128;
      final cr = v[(row ~/ 2) * vRowStride + (col ~/ 2) * vPixelStride] - 128;
      final i = (row * width + col) * 4;
      rgba[i] = byte(298 * luma + 409 * cr + 128);
      rgba[i + 1] = byte(298 * luma - 100 * cb - 208 * cr + 128);
      rgba[i + 2] = byte(298 * luma + 516 * cb + 128);
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

/// Rotate owned pixel rows before inference so the model and preview consume
/// the same upright image. Strip row padding and preserve channel order.
VisionImage orientPoseImage(VisionImage image, int rotation) {
  if (rotation == 0 &&
      image.bytesPerRow == image.width! * image.format!.channels) {
    return image;
  }
  if (rotation != 0 && rotation != 90 && rotation != 180 && rotation != 270) {
    throw ArgumentError.value(rotation, 'rotation', 'Expected a quarter turn');
  }
  final width = image.width!;
  final height = image.height!;
  final channels = image.format!.channels;
  final source = image.pixels!;
  final outWidth = rotation == 0 || rotation == 180 ? width : height;
  final outHeight = rotation == 0 || rotation == 180 ? height : width;
  final pixels = Uint8List(outWidth * outHeight * channels);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (dx, dy) = switch (rotation) {
        0 => (x, y),
        90 => (height - 1 - y, x),
        180 => (width - 1 - x, height - 1 - y),
        _ => (y, width - 1 - x),
      };
      final from = y * image.bytesPerRow! + x * channels;
      final to = (dy * outWidth + dx) * channels;
      pixels.setRange(to, to + channels, source, from);
    }
  }
  return VisionImage.fromPixels(
    pixels: pixels,
    width: outWidth,
    height: outHeight,
    format: image.format!,
  );
}

/// Runs on a worker isolate. Camera planes contain owned Dart byte buffers.
VisionImage preparePoseImage((CameraImage, int) request) =>
    orientPoseImage(visionImageFromCamera(request.$1), request.$2);
