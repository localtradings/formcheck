import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/pose_frame.dart';
import 'package:formcheck/application/camera_frame.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:formcheck/domain/rep_analyzer.dart';
import 'package:formcheck/presentation/pose_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('camera pixels rotate exactly with padded RGBA and BGRA rows', () async {
    const orders = {
      0: [1, 2, 3, 4],
      90: [3, 1, 4, 2],
      180: [4, 3, 2, 1],
      270: [2, 4, 1, 3],
    };
    for (final format in [VisionPixelFormat.rgba, VisionPixelFormat.bgra]) {
      final input = VisionImage.fromPixels(
        pixels: Uint8List.fromList([
          1,
          0,
          0,
          255,
          2,
          0,
          0,
          255,
          99,
          99,
          99,
          99,
          3,
          0,
          0,
          255,
          4,
          0,
          0,
          255,
          99,
          99,
          99,
          99,
        ]),
        width: 2,
        height: 2,
        bytesPerRow: 12,
        format: format,
      );
      for (final entry in orders.entries) {
        final rotated = orientPoseImage(input, entry.key);
        expect(rotated.format, format);
        final image = await decodePoseFrame(rotated);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        image.dispose();
        // BGRA puts the marker in blue. RGBA puts it in red.
        final channel = format == VisionPixelFormat.bgra ? 2 : 0;
        expect([
          for (var i = 0; i < 4; i++) bytes.getUint8(i * 4 + channel),
        ], entry.value);
      }
    }
  });

  test('pixels and skeleton agree through rotation, mirror and letterboxing', () async {
    final source = ui.PictureRecorder();
    final imageCanvas = ui.Canvas(source);
    imageCanvas.drawRect(
      const ui.Rect.fromLTWH(28, 22, 5, 5),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    );
    final picture = source.endRecording();
    final image = await picture.toImage(40, 32);
    picture.dispose();
    addTearDown(image.dispose);
    const joint = Joint(.75, .75, 1);
    // Independently specified positions in the upright image for each rotation.
    const expected = [
      ui.Offset(.75, .75),
      ui.Offset(.25, .75),
      ui.Offset(.25, .25),
      ui.Offset(.75, .25),
    ];
    for (var turns = 0; turns < 4; turns++) {
      for (final mirror in [false, true]) {
        for (final view in [const ui.Size(200, 300), const ui.Size(300, 150)]) {
          final geometry = PoseFrameGeometry(
            width: 40,
            height: 32,
            rotation: turns * 90,
            mirror: mirror,
          );
          final size = turns.isOdd
              ? const ui.Size(32, 40)
              : const ui.Size(40, 32);
          final scale = (view.width / size.width) < (view.height / size.height)
              ? view.width / size.width
              : view.height / size.height;
          final target = ui.Offset(
            (view.width - size.width * scale) / 2 +
                (mirror ? 1 - expected[turns].dx : expected[turns].dx) *
                    size.width *
                    scale,
            (view.height - size.height * scale) / 2 +
                expected[turns].dy * size.height * scale,
          );
          expect(
            (geometry.project(joint, view) - target).distance,
            lessThan(0.001),
          );

          Future<ui.Color> render(bool skeleton) async {
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            if (skeleton) {
              final joints = List.filled(33, const Joint(0, 0, 0));
              joints[11] = const Joint(.25, .25, 1);
              joints[13] = joint;
              PosePainter(PoseFrame(image, geometry, [joints], 100))
                  .paint(canvas, view);
            } else {
              geometry.paintImage(canvas, view, image);
            }
            final picture = recorder.endRecording();
            final rendered = await picture.toImage(
              view.width.toInt(),
              view.height.toInt(),
            );
            picture.dispose();
            final bytes = (await rendered.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            rendered.dispose();
            final index =
                (target.dy.floor() * view.width.toInt() + target.dx.floor()) *
                4;
            return ui.Color.fromARGB(
              bytes.getUint8(index + 3),
              bytes.getUint8(index),
              bytes.getUint8(index + 1),
              bytes.getUint8(index + 2),
            );
          }

          // The independently placed red body marker and the real skeleton
          // endpoint must occupy the identical pixel on the fitted preview.
          expect(await render(false), const ui.Color(0xFFFF0000));
          final bone = await render(true);
          expect(bone.g, greaterThan(.9));
          expect(bone.r, greaterThan(.6));
          expect(bone.b, lessThan(.7));
        }
      }
    }
  });

  test('camera geometry distinguishes upright iOS buffers and Android sensor buffers', () {
    PoseFrameGeometry geometry(
      TargetPlatform platform,
      CameraLensDirection lens,
      DeviceOrientation orientation,
      int width,
      int height,
      int sensor,
    ) => PoseFrameGeometry.camera(
      width: width,
      height: height,
      sensorOrientation: sensor,
      lens: lens,
      orientation: orientation,
      platform: platform,
    );

    final ios = geometry(
      TargetPlatform.iOS,
      CameraLensDirection.front,
      DeviceOrientation.portraitUp,
      480,
      720,
      90,
    );
    expect(ios.rotation, 0);
    expect(ios.mirror, isFalse);
    expect(ios.aspect, 2 / 3);
    final android = geometry(
      TargetPlatform.android,
      CameraLensDirection.front,
      DeviceOrientation.portraitUp,
      640,
      480,
      270,
    );
    expect(android.rotation, 270);
    expect(android.mirror, isTrue);
    expect(android.aspect, .75);
    final back = geometry(
      TargetPlatform.android,
      CameraLensDirection.back,
      DeviceOrientation.landscapeLeft,
      640,
      480,
      90,
    );
    expect(back.rotation, 0);
    expect(back.mirror, isFalse);
  });
}
