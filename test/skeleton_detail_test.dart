import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/pose_frame.dart';
import 'package:formcheck/domain/rep_analyzer.dart';
import 'package:formcheck/domain/workout.dart';
import 'package:formcheck/presentation/pose_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('renders reliable head, thumb and heel landmarks', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF000000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 300);
    picture.dispose();
    addTearDown(image.dispose);
    final joints = List.filled(33, const Joint(0, 0, 0));
    joints[0] = const Joint(.5, .12, 1);
    joints[2] = const Joint(.47, .10, 1);
    joints[7] = const Joint(.43, .12, 1);
    joints[11] = const Joint(.35, .28, 1);
    joints[15] = const Joint(.2, .55, 1);
    joints[21] = const Joint(.16, .58, 1);
    joints[27] = const Joint(.4, .88, 1);
    joints[29] = const Joint(.38, .91, 1);
    joints[31] = const Joint(.47, .92, 1);
    final output = ui.PictureRecorder();
    PosePainter(
      PoseFrame(
        image,
        const PoseFrameGeometry(
          width: 200,
          height: 300,
          rotation: 0,
          mirror: false,
        ),
        [joints],
        100,
      ),
    ).paint(ui.Canvas(output), const ui.Size(200, 300));
    final renderedPicture = output.endRecording();
    final rendered = await renderedPicture.toImage(200, 300);
    renderedPicture.dispose();
    final bytes = (await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    rendered.dispose();
    for (final index in [0, 21, 29]) {
      final joint = joints[index];
      final offset =
          ((joint.y * 300).round() * 200 + (joint.x * 200).round()) * 4;
      expect(
        bytes.getUint8(offset + 1),
        greaterThan(200),
        reason: 'Landmark $index should be visible in the complete skeleton',
      );
    }
  });

  test('the measured bend follows its exercise, anatomical side and preview mirror', () async {
    final background = ui.PictureRecorder();
    ui.Canvas(background)
        .drawColor(const ui.Color(0xFF000000), ui.BlendMode.src);
    final picture = background.endRecording();
    final image = await picture.toImage(200, 160);
    picture.dispose();
    addTearDown(image.dispose);
    final joints = List.filled(33, const Joint(0, 0, 0));
    for (final (index, x, y) in [
      (11, .32, .12),
      (13, .19, .12),
      (15, .19, .35),
      (12, .78, .16),
      (14, .62, .16),
      (16, .62, .38),
      (23, .25, .18),
      (25, .25, .48),
      (27, .47, .48),
      (24, .68, .21),
      (26, .68, .56),
      (28, .90, .56),
    ]) {
      joints[index] = Joint(x, y, 1);
    }
    const size = ui.Size(200, 160);
    Future<ByteData> render(
      PoseFrameGeometry geometry,
      MeasuredJoint? measuredJoint, {
      bool twoPeople = false,
    }) async {
      final recorder = ui.PictureRecorder();
      PosePainter(
        PoseFrame(image, geometry, [joints, if (twoPeople) joints], 100),
        measuredJoint: measuredJoint,
      ).paint(ui.Canvas(recorder), size);
      final drawing = recorder.endRecording();
      final rendered = await drawing.toImage(200, 160);
      drawing.dispose();
      final bytes = (await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      rendered.dispose();
      return bytes;
    }

    bool amberNear(ByteData data, ui.Offset target, [int radius = 2]) {
      for (
        var y = target.dy.round() - radius;
        y <= target.dy.round() + radius;
        y++
      ) {
        for (
          var x = target.dx.round() - radius;
          x <= target.dx.round() + radius;
          x++
        ) {
          final i = (y * 200 + x) * 4;
          if (data.getUint8(i) > 235 &&
              data.getUint8(i + 1) < 225 &&
              data.getUint8(i + 1) > 170 &&
              data.getUint8(i + 2) < 160) {
            return true;
          }
        }
      }
      return false;
    }

    for (final mirror in [false, true]) {
      final geometry = PoseFrameGeometry(
        width: 200,
        height: 160,
        rotation: 0,
        mirror: mirror,
      );
      for (final (exercise, bend) in [
        (Exercise.squat, 25),
        (Exercise.pushUp, 13),
      ]) {
        for (final side in [0, 1]) {
          final data = await render(geometry, (exercise: exercise, side: side));
          final joint = geometry.project(joints[bend + side], size);
          expect(amberNear(data, joint, 6), isTrue);
          final otherSide = geometry.project(joints[bend + 1 - side], size);
          expect(amberNear(data, otherSide, 6), isFalse);
          final otherBend = geometry.project(
            joints[(bend == 25 ? 13 : 25) + side],
            size,
          );
          expect(amberNear(data, otherBend, 6), isFalse);
          if (exercise == Exercise.squat && side == 0) {
            // The knee opens up and to the right in the original image.
            expect(
              amberNear(data, joint + ui.Offset(mirror ? -11 : 11, -11)),
              isTrue,
            );
            expect(
              amberNear(data, joint + ui.Offset(mirror ? 11 : -11, -11)),
              isFalse,
            );
          }
        }
      }
    }
    const geometry = PoseFrameGeometry(
      width: 200,
      height: 160,
      rotation: 0,
      mirror: false,
    );
    const measured = (exercise: Exercise.squat, side: 0);
    final knee = geometry.project(joints[25], size);
    expect(amberNear(await render(geometry, null), knee, 6), isFalse);
    expect(
      amberNear(await render(geometry, measured, twoPeople: true), knee, 6),
      isFalse,
    );
    joints[23] = const Joint(.25, .18, .60);
    expect(amberNear(await render(geometry, measured), knee, 6), isFalse);
  });
}
