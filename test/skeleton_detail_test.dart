import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/pose_frame.dart';
import 'package:formcheck/domain/rep_analyzer.dart';
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
}
