import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcheck/application/providers.dart';
import 'package:formcheck/data/workout_store.dart';
import 'package:formcheck/domain/workout.dart';
import 'package:formcheck/presentation/formcheck_app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'opens camera-first with a real setup action and navigates to Gym',
    (tester) async {
      final store = WorkoutStore(NativeDatabase.memory());
      addTearDown(store.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workoutStoreProvider.overrideWithValue(store)],
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
