import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/providers.dart';
import 'package:formcheck/domain/workout.dart';
import 'package:formcheck/presentation/camera_page.dart';
import 'package:formcheck/presentation/camera_placement_guide.dart';
import 'package:formcheck/presentation/formcheck_app.dart';
import 'package:formcheck/presentation/theme.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: formTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'the camera tab shows the selected exercise’s angle and height before permission',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyProvider.overrideWith(
              (_) => Stream.value(const <SetRecord>[]),
            ),
          ],
          child: const FormCheckApp(),
        ),
      );
      expect(find.text('Squat camera setup'), findsOneWidget);
      expect(find.text('90° to the way you face'), findsOneWidget);
      expect(find.text('At standing hip height'), findsOneWidget);
      await tester.tap(find.text('Push-up'));
      await tester.pumpAndSettle();
      expect(find.text('Push-up camera setup'), findsOneWidget);
      expect(find.text('90° to your mat’s length'), findsOneWidget);
      expect(find.text('Low, at mid-torso height'), findsOneWidget);
      expect(find.text('At standing hip height'), findsNothing);
      expect(find.text('Open camera'), findsOneWidget);
    },
  );

  testWidgets(
    'illustrations show either side and different sight lines for squat and push-up',
    (tester) async {
      Future<List<Uint8List>> draw(Exercise exercise) async {
        await tester.pumpWidget(
          _host(CameraPlacementGuide(exercise: exercise)),
        );
        final painted = find.descendant(
          of: find.byType(CameraPlacementGuide),
          matching: find.byType(CustomPaint),
        );
        final diagrams = tester.widgetList<CustomPaint>(painted).toList();
        expect(diagrams, hasLength(2));
        final images = await tester.runAsync(() async {
          final results = <Uint8List>[];
          for (final widget in diagrams) {
            final recorder = ui.PictureRecorder();
            widget.painter!.paint(ui.Canvas(recorder), const Size(148, 82));
            final picture = recorder.endRecording();
            final image = await picture.toImage(148, 82);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            results.add(bytes!.buffer.asUint8List());
            image.dispose();
            picture.dispose();
          }
          return results;
        });
        return images!;
      }

      final squat = await draw(Exercise.squat);
      final pushUp = await draw(Exercise.pushUp);
      int alpha(Uint8List image, int x, int y) => image[(y * 148 + x) * 4 + 3];
      for (final diagram in [squat[0], pushUp[0]]) {
        expect(alpha(diagram, 13, 37), greaterThan(80));
        expect(alpha(diagram, 135, 37), greaterThan(80));
      }
      expect(alpha(squat[0], 79, 73), 0);
      expect(alpha(pushUp[0], 79, 73), greaterThan(80));
      expect(alpha(squat[1], 23, 43), greaterThan(60));
      expect(alpha(pushUp[1], 23, 43), 0);
      expect(alpha(pushUp[1], 23, 53), greaterThan(60));
      expect(alpha(squat[1], 23, 53), 0);
    },
  );

  testWidgets(
    'live angles distinguish targets, observations and unavailable readings at 2× text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _host(
          const LiveCameraAngles(
            exercise: Exercise.pushUp,
            placementLabel: 'Checking the side view',
            sideAngle: 75,
            lensTilt: 4,
            jointAngle: 138,
          ),
        ),
      );
      expect(find.text('90° side target'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Estimated camera angle 75 degrees. Target 90 degrees from either side.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Lens tilt, 4 degrees, target 0°'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Live elbow angle, about 138 degrees'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _host(
          const LiveCameraAngles(
            exercise: Exercise.squat,
            placementLabel: 'Angle unavailable',
            sideAngle: null,
            lensTilt: null,
            jointAngle: null,
          ),
        ),
      );
      expect(find.text('Side angle ≈75°'), findsNothing);
      expect(
        find.bySemanticsLabel('Side angle, unavailable, target 90°'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Live knee angle, unavailable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'set review reads the selected rep and clears missing measurements',
    (tester) async {
      const reps = [
        RepResult(RepOutcome.passed, null, 91),
        RepResult(RepOutcome.needsCorrection, Cue.squatDepth, 118),
        RepResult(RepOutcome.unassessed, Cue.reframe),
      ];
      await tester.pumpWidget(
        _host(
          const RepCheckDetails(
            exercise: Exercise.squat,
            reps: reps,
            review: true,
          ),
        ),
      );
      expect(find.text('Rep 3 · Couldn’t assess'), findsOneWidget);
      expect(find.textContaining('Bottom knee angle'), findsNothing);
      await tester.tap(find.byTooltip('Previous rep'));
      await tester.pump();
      expect(find.text('Rep 2 · Needs correction'), findsOneWidget);
      expect(
        find.text('Your knee stayed more open than the squat depth target.'),
        findsOneWidget,
      );
      expect(find.textContaining('Bottom knee angle ≈118°'), findsOneWidget);
      await tester.tap(find.byTooltip('Next rep'));
      await tester.pump();
      expect(find.textContaining('Bottom knee angle'), findsNothing);
      await tester.pumpWidget(
        _host(
          const RepCheckDetails(
            exercise: Exercise.pushUp,
            reps: [RepResult(RepOutcome.passed, null, 97)],
            review: true,
            showTarget: false,
          ),
        ),
      );
      expect(find.text('Bottom elbow angle ≈97°'), findsOneWidget);
      expect(find.textContaining('depth target'), findsNothing);
      expect(find.byTooltip('Previous rep'), findsNothing);
    },
  );
}
