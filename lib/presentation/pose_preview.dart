import 'package:flutter/widgets.dart';

import '../application/pose_frame.dart';
import 'theme.dart';

const _poseConnections = <(int, int)>[
  (11, 12),
  (11, 13),
  (13, 15),
  (12, 14),
  (14, 16),
  (11, 23),
  (12, 24),
  (23, 24),
  (23, 25),
  (25, 27),
  (24, 26),
  (26, 28),
  (27, 31),
  (28, 32),
];

/// The image and skeleton share a frame and a contain-fit transform.
class PosePreview extends StatelessWidget {
  const PosePreview({super.key, required this.frame});
  final PoseFrame frame;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: PosePainter(frame), size: Size.infinite);
}

class PosePainter extends CustomPainter {
  const PosePainter(this.frame);
  final PoseFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    frame.geometry.paintImage(canvas, size, frame.image);
    if (frame.people.length == 1) {
      final joints = frame.people.single;
      final limbs = Paint()
        ..color = lime
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (final (start, end) in _poseConnections) {
        if (end >= joints.length || start >= joints.length) continue;
        if (!joints[start].visible || !joints[end].visible) continue;
        final a = frame.geometry.project(joints[start], size);
        final b = frame.geometry.project(joints[end], size);
        canvas.drawLine(a, b, limbs);
        canvas.drawCircle(b, 2.8, limbs);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
