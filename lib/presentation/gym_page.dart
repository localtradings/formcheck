import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/workout.dart';
import 'theme.dart';

class GymPage extends StatelessWidget {
  const GymPage({super.key, required this.onExercise});
  final ValueChanged<Exercise> onExercise;

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Text('Gym', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 20),
      const SectionTitle('Bodyweight starter'),
      const SizedBox(height: 6),
      const Text('Two sets of five per exercise. Rest between sets.'),
      const SizedBox(height: 14),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final exercise in [Exercise.squat, Exercise.pushUp])
              ListTile(
                leading: const Icon(Icons.fitness_center_rounded, color: lime),
                title: Text(exercise.label),
                subtitle: const Text('2 sets · 5 reps'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => onExercise(exercise),
              ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      RaisedAction(
        label: 'Log a set manually',
        icon: Icons.add_rounded,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => const _ManualLog(),
        ),
      ),
    ],
  );
}

class _ManualLog extends ConsumerStatefulWidget {
  const _ManualLog();

  @override
  ConsumerState<_ManualLog> createState() => _ManualLogState();
}

class _ManualLogState extends ConsumerState<_ManualLog> {
  final _form = GlobalKey<FormState>();
  final _reps = TextEditingController();
  final _weight = TextEditingController();
  Exercise _exercise = Exercise.dumbbellRow;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final weight = _weight.text.trim().replaceAll(',', '.');
      await ref
          .read(workoutStoreProvider)
          .saveManual(
            _exercise,
            int.parse(_reps.text.trim()),
            double.tryParse(weight),
          );
      if (mounted) Navigator.of(context).pop();
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Couldn’t save this set. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Log a set'),
            const SizedBox(height: 16),
            DropdownButtonFormField<Exercise>(
              initialValue: _exercise,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Exercise'),
              items: [
                for (final e in Exercise.values)
                  DropdownMenuItem(value: e, child: Text(e.label)),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _exercise = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reps,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
              validator: (value) {
                final reps = int.tryParse(value?.trim() ?? '');
                return reps == null || reps < 1 || reps > 999
                    ? 'Enter 1 to 999 reps.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weight,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight in kg (optional)',
              ),
              validator: (value) {
                final input = value?.trim().replaceAll(',', '.') ?? '';
                if (input.isEmpty) return null;
                final weight = double.tryParse(input);
                return weight == null ||
                        !weight.isFinite ||
                        weight < 0 ||
                        weight > 1000
                    ? 'Enter a weight from 0 to 1,000 kg.'
                    : null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_error!)),
            ],
            const SizedBox(height: 18),
            RaisedAction(
              label: _saving ? 'Saving…' : 'Save set',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
