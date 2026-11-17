import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/pose_overlay_filter.dart';
import 'package:formcheck/domain/rep_analyzer.dart';

void main() {
  List<Joint> pose({double x = .5, double confidence = .9}) => [
    for (var i = 0; i < 33; i++)
      Joint(i == 13 ? x : .5, .5, i == 13 ? confidence : .9),
  ];

  test('damps static jitter, bounds motion lag and preserves original measurements', () {
    final filter = PoseOverlayFilter();
    var rawError = 0.0, filteredError = 0.0;
    for (var i = 0; i < 60; i++) {
      final x = .5 + (i.isEven ? -.006 : .006);
      final raw = pose(x: x);
      final result = filter.accept(PoseSample(i * 50, .7, [raw])).single[13];
      if (i > 10) {
        rawError += math.pow(x - .5, 2);
        filteredError += math.pow(result.x - .5, 2);
      }
      expect(
        raw[13].x,
        x,
        reason: 'Display filtering cannot modify assessment input',
      );
    }
    expect(filteredError, lessThan(rawError * .65));
    for (var i = 0; i < 10; i++) {
      final x = i.isEven ? .2 : .8;
      final result = filter
          .accept(PoseSample(3000 + i * 50, .7, [pose(x: x)]))
          .single[13];
      expect((result.x - x).abs() * .7, lessThanOrEqualTo(.012001));
    }
  });

  test('one confidence dip stays visible, absent or persistently weak joints do not', () {
    final filter = PoseOverlayFilter();
    filter.accept(PoseSample(0, 1, [pose()]));
    final dip = pose(confidence: .58);
    final result = filter.accept(PoseSample(50, 1, [dip])).single[13];
    expect(PoseOverlayFilter.canDraw(result), isTrue);
    expect(
      dip[13].visible,
      isFalse,
      reason: 'Assessment keeps the strict confidence cutoff',
    );
    expect(
      PoseOverlayFilter.canDraw(
        filter.accept(PoseSample(100, 1, [pose(confidence: 0)])).single[13],
      ),
      isFalse,
    );
    expect(
      PoseOverlayFilter.canDraw(
        filter.accept(PoseSample(150, 1, [dip])).single[13],
      ),
      isFalse,
    );
    filter.accept(PoseSample(200, 1, [pose()]));
    filter.accept(PoseSample(300, 1, [dip]));
    expect(
      PoseOverlayFilter.canDraw(
        filter.accept(PoseSample(400, 1, [dip])).single[13],
      ),
      isFalse,
    );
  });

  test('clears state across missing people, identity shifts, gaps and invalid coordinates', () {
    final filter = PoseOverlayFilter();
    filter.accept(PoseSample(0, 1, [pose()]));
    expect(filter.accept(PoseSample(50, 1, [pose(), pose()])), isEmpty);
    expect(
      PoseOverlayFilter.canDraw(
        filter.accept(PoseSample(100, 1, [pose(confidence: .58)])).single[13],
      ),
      isFalse,
    );
    filter.accept(PoseSample(150, 1, [pose()]));
    final invalid = pose(x: double.nan);
    expect(
      PoseOverlayFilter.canDraw(
        filter.accept(PoseSample(200, 1, [invalid])).single[13],
      ),
      isFalse,
    );
    filter.accept(PoseSample(250, 1, [pose()]));
    expect(
      PoseOverlayFilter.canDraw(
        filter.accept(PoseSample(600, 1, [pose(confidence: .58)])).single[13],
      ),
      isFalse,
    );
    filter.accept(PoseSample(650, 1, [pose()]));
    final moved = [for (final p in pose()) Joint(p.x + .3, p.y, p.visibility)];
    expect(filter.accept(PoseSample(700, 1, [moved])).single[13].x, .8);
    expect(filter.accept(PoseSample(699, 1, [pose()])), isEmpty);
    filter.accept(PoseSample(750, 1, [pose()]));
    filter.reset();
    expect(
      PoseOverlayFilter.canDraw(
        filter.accept(PoseSample(800, 1, [pose(confidence: .58)])).single[13],
      ),
      isFalse,
    );
  });
}
