import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/workout_store.dart';
import '../domain/workout.dart';
import 'coach.dart';
import 'pose_capture.dart';

String newWorkoutId() => const Uuid().v4();

final workoutStoreProvider = Provider((ref) {
  final store = WorkoutStore();
  ref.onDispose(() => unawaited(store.close()));
  return store;
});

final historyProvider = StreamProvider<List<SetRecord>>(
  (ref) => ref.watch(workoutStoreProvider).watch(),
);

final coachProvider = Provider(
  (ref) => SetCoach(ref.watch(workoutStoreProvider)),
);

final cameraProvider = Provider((ref) {
  final capture = PoseCapture();
  ref.onDispose(capture.dispose);
  return capture;
});
