import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/domain/camera_framing.dart';
import 'package:formcheck/domain/rep_analyzer.dart';
import 'package:formcheck/domain/workout.dart';

const _hidden = Joint(0, 0, 0);

List<Joint> _squat({double scale = 1, double x = .5, double y = .5}) {
  final points = List.filled(33, _hidden);
  points[11] = Joint(x, y - .28 * scale, .98);
  points[23] = Joint(x, y - .03 * scale, .97);
  points[25] = Joint(x + .03 * scale, y + .13 * scale, .96);
  points[27] = Joint(x, y + .29 * scale, .95);
  return points;
}

List<Joint> _pushUp() {
  final points = List.filled(33, _hidden);
  points[12] = const Joint(.70, .44, .98);
  points[14] = const Joint(.70, .55, .96);
  points[16] = const Joint(.71, .66, .95);
  points[24] = const Joint(.48, .47, .97);
  points[28] = const Joint(.22, .49, .96);
  return points;
}

final class _Camera {
  _Camera(Exercise exercise, {this.min = 1, this.max = 3, this.aspect = .75})
    : framing = CameraFraming(exercise);

  final CameraFraming framing;
  final double min;
  final double max;
  final double aspect;
  int now = 0;
  double zoom = 1;
  bool recording = false;
  TrackingStatus tracking = TrackingStatus.getReady;
  final commands = <double>[];
  int widerPulses = 0;

  void show(List<List<Joint>> people, {int frames = 1, int stepMs = 100}) {
    for (var frame = 0; frame < frames; frame++) {
      now += stepMs;
      final command = framing.update(
        PoseSample(now, aspect, people),
        currentZoom: zoom,
        minZoom: min,
        maxZoom: max,
        recording: recording,
        tracking: tracking,
      );
      if (command != null) {
        commands.add(command);
        zoom = command;
      }
      if (framing.needsWiderLens) widerPulses++;
    }
  }
}

void main() {
  test(
    'a protected rep cannot spend the wider-lens request needed after loss',
    () {
      final camera = _Camera(Exercise.squat, max: 1)
        ..recording = true
        ..tracking = TrackingStatus.ready;
      camera.show([], frames: 30);
      expect(camera.widerPulses, 0);
      camera.tracking = TrackingStatus.reposition;
      camera.show([], frames: 8);
      expect(camera.widerPulses, 0);
      camera.show([], frames: 15);
      expect(camera.widerPulses, 1);
    },
  );

  test(
    'uses one visible exercise chain and ignores an unseen far side or face',
    () {
      for (final aspect in [.56, 1.78]) {
        final squat = _Camera(Exercise.squat, aspect: aspect);
        final nearSide = _squat();
        nearSide[28] = const Joint(3, -4, .99);
        squat.show([nearSide], frames: 25);
        expect(squat.framing.issue, FramingIssue.clear);
        expect(squat.commands, isEmpty);
        final pushUp = _Camera(Exercise.pushUp, aspect: aspect);
        pushUp.show([_pushUp()], frames: 25);
        expect(pushUp.framing.issue, FramingIssue.clear);
        expect(pushUp.commands, isEmpty);
      }
      final mixed = _squat(scale: .42);
      for (final index in [11, 23, 25]) {
        mixed[index + 1] = mixed[index];
      }
      mixed[25] = _hidden;
      final camera = _Camera(Exercise.squat);
      camera.show([mixed], frames: 35);
      expect(camera.framing.issue, FramingIssue.missingLegs);
      expect(camera.commands, isEmpty);
    },
  );

  test(
    'sustained loss widens to the real minimum and asks for a wider lens once',
    () {
      final camera = _Camera(Exercise.squat, min: .6)..zoom = 1.8;
      camera.show([_squat()], frames: 7);
      camera.show([], frames: 2);
      expect(camera.commands, isEmpty);
      camera.show([_squat()], frames: 6);
      expect(camera.framing.issue, FramingIssue.clear);
      camera.show([], frames: 70);
      expect(camera.framing.issue, FramingIssue.searching);
      expect(camera.commands, [.6]);
      expect(camera.widerPulses, 1);
      camera.show([_squat()], frames: 22);
      camera.show([], frames: 50);
      expect(camera.widerPulses, 2);
    },
  );

  test('second person cancels pending changes on the very first frame', () {
    final camera = _Camera(Exercise.squat, min: .5);
    final small = _squat(scale: .38);
    camera.show([small], frames: 7);
    camera.show([small, small]);
    expect(camera.framing.issue, FramingIssue.multiplePeople);
    camera.show([small, small], frames: 40);
    camera.show([small], frames: 4);
    expect(camera.commands, isEmpty);
    expect(camera.widerPulses, 0);
    camera.show([small], frames: 20);
    expect(camera.commands.single, greaterThan(1));
  });

  test('keeps localized occlusion separate from a near-camera crop', () {
    final camera = _Camera(Exercise.squat, min: .55);
    final blockedAnkle = _squat(scale: .8)..[27] = _hidden;
    camera.show([blockedAnkle], frames: 30);
    expect(camera.framing.issue, FramingIssue.missingLegs);
    expect(camera.commands, isEmpty);

    final upperBody = List.filled(33, _hidden);
    upperBody[11] = const Joint(.57, .18, .99);
    upperBody[23] = const Joint(.5, .54, .99);
    upperBody[27] = const Joint(.49, 1.28, .99);
    camera.show([upperBody], frames: 20);
    expect(camera.framing.issue, FramingIssue.tooClose);
    expect(camera.commands.first, lessThan(1));

    final pushUp = _Camera(Exercise.pushUp);
    pushUp.show([_pushUp()..[16] = _hidden], frames: 32);
    expect(pushUp.framing.issue, FramingIssue.missingArms);
    pushUp.show([_pushUp()..[24] = _hidden], frames: 32);
    expect(pushUp.framing.issue, FramingIssue.missingTorso);
    pushUp.show([_pushUp()..[28] = _hidden], frames: 32);
    expect(pushUp.framing.issue, FramingIssue.missingLegs);
    expect(pushUp.commands, isEmpty);
    expect(pushUp.widerPulses, 0);
  });

  test('zooms only for a settled small subject and reserves crop space', () {
    final camera = _Camera(Exercise.squat, min: .5, max: 1.17);
    final small = _squat(scale: .34);
    camera.show([small], frames: 6);
    expect(camera.framing.issue, FramingIssue.tooFar);
    expect(camera.commands, isEmpty);
    camera.show([small], frames: 45);
    expect(camera.commands, [1.17]);

    final walking = _Camera(Exercise.squat);
    for (var frame = 0; frame < 40; frame++) {
      walking.show([_squat(scale: .34, x: frame ~/ 5 % 2 == 0 ? .43 : .56)]);
    }
    expect(walking.commands, isEmpty);
    walking.show([_squat(scale: .34, x: .84)], frames: 35);
    expect(walking.framing.issue, FramingIssue.offCenter);
    expect(walking.commands, isEmpty);

    final extended = _Camera(Exercise.squat);
    final withHandAtEdge = _squat(scale: .34);
    withHandAtEdge[15] = const Joint(.04, .53, .97);
    extended.show([withHandAtEdge], frames: 35);
    expect(extended.commands, isEmpty);
  });

  test('keeps room to stand up and only tightens for a lengthwise push-up', () {
    final squat = _Camera(Exercise.squat);
    final crouched = _squat(scale: .5);
    crouched[23] = const Joint(.49, .54, .98);
    crouched[25] = const Joint(.60, .55, .97);
    squat.show([crouched], frames: 40);
    expect(squat.commands, isEmpty);

    final pushUp = _Camera(Exercise.pushUp, aspect: 1.78);
    final standing = _squat(scale: .42);
    standing[13] = const Joint(.53, .50, .97);
    standing[15] = const Joint(.53, .54, .97);
    pushUp.show([standing], frames: 40);
    expect(pushUp.commands, isEmpty);
    final smallPlank = [
      for (final p in _pushUp())
        Joint(.5 + (p.x - .5) * .42, .5 + (p.y - .5) * .42, p.visibility),
    ];
    pushUp.show([smallPlank], frames: 20);
    expect(pushUp.commands.single, closeTo(1.35, .001));
  });

  test(
    'never tightens during a set, while disabled, or beyond a fixed lens',
    () {
      final small = _squat(scale: .4);
      final camera = _Camera(Exercise.squat, min: .5)..recording = true;
      camera.show([small], frames: 30);
      expect(camera.commands, isEmpty);
      camera.recording = false;
      camera.tracking = TrackingStatus.moving;
      camera.show([small], frames: 30);
      expect(camera.commands, isEmpty);
      camera.recording = true;
      camera.tracking = TrackingStatus.reposition;
      camera.show([], frames: 20);
      expect(camera.commands.single, .5);

      final fixed = _Camera(Exercise.squat, max: 1);
      fixed.show([small], frames: 40);
      expect(fixed.framing.issue, FramingIssue.tooFar);
      expect(fixed.commands, isEmpty);
      fixed.show([], frames: 50);
      expect(fixed.commands, isEmpty);
      expect(fixed.widerPulses, 1);
    },
  );

  test(
    'gaps, stale samples, invalid values and reset cannot trigger a zoom',
    () {
      final camera = _Camera(Exercise.squat, min: .5);
      final small = _squat(scale: .38);
      camera.show([small], frames: 7);
      camera.show([small], stepMs: 1500);
      camera.show([small], frames: 3);
      camera.show([], stepMs: -50);
      expect(camera.commands, isEmpty);
      expect(camera.widerPulses, 0);
      camera.framing.reset();
      expect(camera.framing.issue, FramingIssue.searching);
      camera.show([small], frames: 3);
      expect(camera.commands, isEmpty);
      final broken = _Camera(
        Exercise.squat,
        min: double.nan,
        aspect: double.nan,
      );
      broken.show([
        List.filled(33, const Joint(double.nan, .5, .99)),
      ], frames: 35);
      expect(broken.commands, isEmpty);
      expect(broken.widerPulses, 0);
      final invalidRange = _Camera(Exercise.squat, min: double.nan);
      invalidRange.show([], frames: 35);
      expect(invalidRange.commands, isEmpty);
      expect(invalidRange.widerPulses, 0);
      final collapsed = _Camera(Exercise.squat);
      collapsed.show([List.filled(33, const Joint(.5, .5, .99))], frames: 40);
      expect(collapsed.commands, isEmpty);
      expect(collapsed.widerPulses, 0);
    },
  );
}
