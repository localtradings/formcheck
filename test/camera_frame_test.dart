import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/camera_frame.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

void main() {
  test(
    'Android planes preserve color, padding and position at every rotation',
    () {
      const luma = [
        16,
        235,
        82,
        126,
        145,
        64,
        128,
        81,
        255,
        40,
        41,
        100,
        0,
        255,
        200,
      ];
      const blue = [128, 90, 54, 240, 128, 0];
      const red = [128, 240, 34, 110, 128, 255];
      const rgb = [
        0x000000,
        0xffffff,
        0xff0100,
        0xff3433,
        0x00ff01,
        0x383838,
        0x828282,
        0xff0000,
        0xffcaca,
        0x008500,
        0x0000ff,
        0x4545ff,
        0x000000,
        0xffffff,
        0xffa100,
      ];
      const orders = {
        0: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        90: [10, 5, 0, 11, 6, 1, 12, 7, 2, 13, 8, 3, 14, 9, 4],
        180: [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
        270: [4, 9, 14, 3, 8, 13, 2, 7, 12, 1, 6, 11, 0, 5, 10],
      };
      for (final planar in [true, false]) {
        final frame = _Frame(5, 3, _Format(ImageFormatGroup.yuv420, 35), [
          _stridedPlane(luma, width: 5, rowStride: 12, pixelStride: 2),
          _stridedPlane(
            blue,
            width: 3,
            rowStride: 8,
            pixelStride: planar ? 1 : 3,
          ),
          _stridedPlane(
            red,
            width: 3,
            rowStride: 5,
            pixelStride: planar ? 1 : 2,
          ),
        ]);
        for (final entry in orders.entries) {
          final upright = preparePoseImage((frame, entry.key));
          final sideways = entry.key == 90 || entry.key == 270;
          expect((upright.width, upright.height), sideways ? (3, 5) : (5, 3));
          expect(upright.bytesPerRow, upright.width! * 4);
          expect(upright.format, VisionPixelFormat.rgba);
          expect(upright.pixels, [
            for (final index in entry.value) ...[
              rgb[index] >> 16,
              (rgb[index] >> 8) & 255,
              rgb[index] & 255,
              255,
            ],
          ]);
        }
        expect(() => preparePoseImage((frame, 45)), throwsArgumentError);
      }
    },
  );

  test('packed camera frames retain channel order and raw row metadata', () {
    for (final raw in [1111970369, 'RGBA']) {
      final plane = _Plane(
        Uint8List.fromList([
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          99,
          99,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
          99,
          99,
        ]),
        10,
        null,
      );
      final frame = _Frame(2, 2, _Format(ImageFormatGroup.bgra8888, raw), [
        plane,
      ]);
      final original = visionImageFromCamera(frame);
      expect(original.bytesPerRow, 10);
      expect(original.pixels, plane.bytes);
      final upright = preparePoseImage((frame, 90));
      expect(
        upright.format,
        raw == 'RGBA' ? VisionPixelFormat.rgba : VisionPixelFormat.bgra,
      );
      expect(upright.bytesPerRow, 8);
      expect(upright.pixels, [
        9,
        10,
        11,
        12,
        1,
        2,
        3,
        4,
        13,
        14,
        15,
        16,
        5,
        6,
        7,
        8,
      ]);
    }
  });
}

_Plane _stridedPlane(
  List<int> samples, {
  required int width,
  required int rowStride,
  required int pixelStride,
}) {
  final rows = samples.length ~/ width;
  final bytes = Uint8List(
    (rows - 1) * rowStride + (width - 1) * pixelStride + 1,
  );
  for (var index = 0; index < samples.length; index++) {
    bytes[(index ~/ width) * rowStride + (index % width) * pixelStride] =
        samples[index];
  }
  return _Plane(bytes, rowStride, pixelStride);
}

class _Frame extends Fake implements CameraImage {
  _Frame(this.width, this.height, this.format, this.planes);
  @override
  final int width;
  @override
  final int height;
  @override
  final ImageFormat format;
  @override
  final List<Plane> planes;
}

class _Format extends Fake implements ImageFormat {
  _Format(this.group, this.raw);
  @override
  final ImageFormatGroup group;
  @override
  final Object raw;
}

class _Plane extends Fake implements Plane {
  _Plane(this.bytes, this.bytesPerRow, this.bytesPerPixel);
  @override
  final Uint8List bytes;
  @override
  final int bytesPerRow;
  @override
  final int? bytesPerPixel;
}
