import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/camera_stream_watchdog.dart';
import 'package:formcheck/application/framing_guidance.dart';
import 'package:formcheck/application/framing_lens.dart';
import 'package:formcheck/domain/camera_framing.dart';
import 'package:formcheck/domain/workout.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

void main() {
  CameraDescription camera(
    String name,
    CameraLensDirection side, [
    CameraLensType type = CameraLensType.unknown,
  ]) {
    return CameraDescription(
      name: name,
      lensDirection: side,
      sensorOrientation: 90,
      lensType: type,
    );
  }

  test('chooses a wider lens only with same-side field of view evidence', () {
    final main = camera('main', CameraLensDirection.back);
    final wide = camera('wide', CameraLensDirection.back);
    final front = camera(
      'opposite',
      CameraLensDirection.front,
      CameraLensType.ultraWide,
    );
    final lenses = [front, main, wide];
    expect(widerLens(main, lenses, {}, 1), isNull);
    expect(
      widerLens(main, lenses, {'main': 1, 'wide': 1.1, 'opposite': 4}, 1),
      isNull,
    );
    expect(widerLens(main, lenses, {'main': 1, 'wide': 1.6}, 1), wide);
    expect(widerLens(main, lenses, {'main': 1, 'wide': 1.6}, .5), isNull);
    final normal = camera(
      'normal',
      CameraLensDirection.back,
      CameraLensType.wide,
    );
    final ultra = camera(
      'ultra',
      CameraLensDirection.back,
      CameraLensType.ultraWide,
    );
    expect(
      defaultLens([front, ultra, normal], CameraLensDirection.back),
      normal,
    );
    expect(widerLens(normal, [front, ultra], {}, 1), ultra);
    expect(widerLens(ultra, [front, normal], {}, 1), isNull);
    expect(widerLens(normal, [front], {}, 1), isNull);
  });

  test(
    'waits for the hardware and allows only one bounded zoom command',
    () async {
      final completion = Completer<void>();
      final commands = <double>[];
      final zoom = FramingZoom(.5, 2, (level) {
        commands.add(level);
        return completion.future;
      });
      await zoom.move(4);
      await zoom.move(double.nan);
      final moving = zoom.move(.5);
      final pending = zoom.move(.8);
      expect(zoom.current, 1);
      expect(zoom.adjusting, isTrue);
      expect(commands, [.5]);
      completion.complete();
      await Future.wait([moving, pending, zoom.idle]);
      expect(zoom.current, .5);
      expect(zoom.adjusting, isFalse);
      await zoom.move(.5);
      expect(commands, [.5]);
    },
  );

  testWidgets(
    'a failed or timed-out zoom keeps tracking at the last accepted level',
    (tester) async {
      for (final hangs in [false, true]) {
        var writes = 0;
        final zoom = FramingZoom(.5, 4, (level) {
          writes++;
          return hangs
              ? Completer<void>().future
              : Future.error(StateError('unavailable'));
        });
        final change = zoom.move(.5);
        await tester.pump(const Duration(seconds: 3));
        await change;
        expect([zoom.minimum, zoom.current, zoom.maximum], [1, 1, 1]);
        await zoom.move(2);
        expect(writes, 1);
      }
    },
  );

  testWidgets(
    'watchdog distinguishes an empty live scene, a stalled stream and a closed session',
    (tester) async {
      final watch = CameraStreamWatchdog();
      var failures = 0;
      watch.start(() => failures++);
      await tester.pump(const Duration(seconds: 7));
      expect(failures, 0);
      for (var frame = 0; frame < 10; frame++) {
        watch.receivedFrame();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(failures, 0);
      await tester.pump(const Duration(seconds: 4));
      expect(failures, 1);
      expect(watch.takeRetry(), isTrue);
      watch.start(() => failures++);
      await tester.pump(const Duration(seconds: 8));
      expect(failures, 2);
      expect(watch.takeRetry(), isTrue);
      expect(watch.takeRetry(), isFalse);
      watch.resetBudget();
      expect(watch.takeRetry(), isTrue);
      watch.start(() => failures++);
      watch.stop();
      await tester.pump(const Duration(seconds: 10));
      watch.receivedFrame();
      await tester.pump(const Duration(seconds: 10));
      expect(failures, 2);
    },
  );

  test(
    'dark-scene guidance uses image content, row stride and channel order',
    () {
      for (final format in [VisionPixelFormat.rgba, VisionPixelFormat.bgra]) {
        VisionImage solid(int red, int green, int blue) {
          final bytes = Uint8List(40 * 8)..fillRange(0, 320, 255);
          for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
              final index = row * 40 + col * 4;
              bytes[index + (format == VisionPixelFormat.rgba ? 0 : 2)] = red;
              bytes[index + 1] = green;
              bytes[index + (format == VisionPixelFormat.rgba ? 2 : 0)] = blue;
            }
          }
          return VisionImage.fromPixels(
            pixels: bytes,
            width: 8,
            height: 8,
            bytesPerRow: 40,
            format: format,
          );
        }

        expect(isDarkCameraFrame(solid(10, 10, 10)), isTrue);
        expect(isDarkCameraFrame(solid(255, 0, 0)), isFalse);
        expect(isDarkCameraFrame(solid(0, 0, 255)), isTrue);
      }
      expect(
        framingPrompt(FramingIssue.searching, Exercise.squat, dim: true),
        contains('light'),
      );
      expect(
        framingPrompt(FramingIssue.missingArms, Exercise.pushUp, dim: true),
        contains('elbow'),
      );
      expect(framingPrompt(FramingIssue.clear, Exercise.squat), isNull);
    },
  );
}
