import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/providers.dart';
import 'package:formcheck/domain/workout.dart';
import 'package:formcheck/presentation/formcheck_app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'opens camera-first with a real setup action and navigates to Gym',
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
      expect(find.text('FormCheck'), findsOneWidget);
      expect(find.text('Open camera'), findsOneWidget);
      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();
      expect(find.text('Bodyweight starter'), findsOneWidget);
      expect(find.text('Log a set manually'), findsOneWidget);
    },
  );

  testWidgets('a temporary focus loss does not restart camera setup', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        historyProvider.overrideWith((_) => Stream.value(const <SetRecord>[])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FormCheckApp(),
      ),
    );
    final capture = container.read(cameraProvider);
    await tester.tap(find.text('Open camera'));
    final opening = capture.busy;
    final error = capture.error;
    var changes = 0;
    capture.addListener(() => changes++);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(changes, 0);
    expect(capture.busy, opening);
    expect(capture.error, error);
    await tester.pumpAndSettle();
  });

  testWidgets('camera layout supports narrow screens with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyProvider.overrideWith(
            (_) => const Stream<List<SetRecord>>.empty(),
          ),
        ],
        child: const FormCheckApp(),
      ),
    );
    expect(find.text('Open camera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
