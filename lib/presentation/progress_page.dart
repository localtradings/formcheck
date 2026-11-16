import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/workout.dart';
import 'theme.dart';

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final store = ref.read(workoutStoreProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout history?'),
        content: const Text(
          'This removes all workout sets and saved coaching from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete history'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.deleteAll();
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t delete history. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      Text('Progress', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 20),
      ref
          .watch(historyProvider)
          .when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading workout history',
              ),
            ),
            error: (_, _) => Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Workout history couldn’t be opened.'),
                  TextButton(
                    onPressed: () => ref.invalidate(historyProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (sets) {
              if (sets.isEmpty) {
                return const Panel(
                  child: Text(
                    'Finish a camera set or log a set in Gym to see your progress here.',
                  ),
                );
              }
              final groups = <(Exercise, String), List<SetRecord>>{};
              final sessions = <String, List<SetRecord>>{};
              for (final set in sets) {
                sessions.putIfAbsent(set.sessionId, () => []).add(set);
                if (set.isCamera && set.profile != null) {
                  groups
                      .putIfAbsent((set.exercise, set.profile!), () => [])
                      .add(set);
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (groups.isNotEmpty) ...[
                    const SectionTitle('Form checks'),
                    const SizedBox(height: 10),
                    for (final entry in groups.entries) ...[
                      _FormTrend(exercise: entry.key.$1, sets: entry.value),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                  ],
                  const SectionTitle('Recent workouts'),
                  const SizedBox(height: 10),
                  for (final session in sessions.values) ...[
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(session.first.at.toLocal()),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final set in session)
                            Padding(
                              padding: const EdgeInsets.only(top: 9),
                              child: Text(
                                set.isCamera
                                    ? '${set.exercise.label} · ${set.passed} passed · ${set.needsCorrection} to adjust · ${set.unassessed} unassessed'
                                    : '${set.exercise.label} · ${set.total} reps${set.weightKg == null ? '' : ' · ${set.weightKg} kg'} · Manual',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _confirmDelete(context, ref),
                      child: const Text('Delete workout history'),
                    ),
                  ),
                ],
              );
            },
          ),
    ],
  );
}

class _FormTrend extends StatelessWidget {
  const _FormTrend({required this.exercise, required this.sets});
  final Exercise exercise;
  final List<SetRecord> sets;

  @override
  Widget build(BuildContext context) {
    final latest = sets.first;
    final ratio = latest.assessed == 0 ? null : latest.passed / latest.assessed;
    final prior = sets.skip(1).where((set) => set.assessed > 0).firstOrNull;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(exercise.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            ratio == null
                ? 'Latest set could not be assessed'
                : '${latest.passed} of ${latest.assessed} assessed reps passed',
          ),
          if (ratio != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: line,
                semanticsLabel: 'Latest pass rate',
                semanticsValue: '${(ratio * 100).round()} percent',
              ),
            ),
            if (prior != null) ...[
              const SizedBox(height: 8),
              Text(
                'Previous comparable set · ${prior.passed} of ${prior.assessed} passed',
                style: const TextStyle(color: soft),
              ),
            ],
          ],
          if (latest.unassessed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${latest.unassessed} unassessed in latest set',
                style: const TextStyle(color: soft),
              ),
            ),
        ],
      ),
    );
  }
}
