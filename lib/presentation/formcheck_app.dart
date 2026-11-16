import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';

import '../domain/workout.dart';
import 'camera_page.dart';
import 'gym_page.dart';
import 'progress_page.dart';
import 'theme.dart';

class FormCheckApp extends StatelessWidget {
  const FormCheckApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FormCheck',
    debugShowCheckedModeBanner: false,
    theme: formTheme(),
    home: const _Home(),
  );
}

class _Home extends ConsumerStatefulWidget {
  const _Home();

  @override
  ConsumerState<_Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<_Home> {
  int _tab = 0;
  Exercise _exercise = Exercise.squat;

  void _openExercise(Exercise exercise) {
    if (exercise != _exercise && ref.read(cameraProvider).recording) {
      setState(() => _tab = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish your current set before switching exercises.'),
        ),
      );
      return;
    }
    setState(() {
      _exercise = exercise;
      _tab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 660;
    const destinations = [
      (Icons.videocam_outlined, Icons.videocam_rounded, 'Camera'),
      (Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Gym'),
      (Icons.insights_outlined, Icons.insights_rounded, 'Progress'),
    ];
    final page = IndexedStack(
      index: _tab,
      children: [
        TickerMode(
          enabled: _tab == 0,
          child: CameraPage(
            active: _tab == 0,
            exercise: _exercise,
            onExercise: _openExercise,
          ),
        ),
        TickerMode(
          enabled: _tab == 1,
          child: GymPage(onExercise: _openExercise),
        ),
        TickerMode(enabled: _tab == 2, child: const ProgressPage()),
      ],
    );
    return Scaffold(
      body: wide
          ? Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    backgroundColor: canvas,
                    labelType: NavigationRailLabelType.all,
                    selectedIndex: _tab,
                    onDestinationSelected: (index) =>
                        setState(() => _tab = index),
                    destinations: [
                      for (final (icon, selected, name) in destinations)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          selectedIcon: Icon(selected),
                          label: Text(name),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: line),
                Expanded(child: page),
              ],
            )
          : page,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: surface,
              indicatorColor: const Color(0xFF32402A),
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: [
                for (final (icon, selected, name) in destinations)
                  NavigationDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected, color: lime),
                    label: name,
                  ),
              ],
            ),
    );
  }
}
