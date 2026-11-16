import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/workout_store.dart';
import '../domain/workout.dart';

typedef CoachReply = ({String text, CoachSource source});

class SetCoach {
  SetCoach(this.store, {Future<CoachReply> Function(String)? generate})
    : _generate = generate ?? _nativeGenerate;

  final WorkoutStore store;
  final Future<CoachReply> Function(String) _generate;
  final Map<String, Future<CoachAdvice>> _active = {};
  static const _channel = MethodChannel('formcheck/coach');
  static const _cloudModel = 'gemini-3.8-flash';

  Future<CoachAdvice> review(SetRecord record) {
    final existing = _active[record.id];
    if (existing != null) return existing;
    if (_active.isNotEmpty) return Future.value(builtIn(record));
    final request = _review(record)
        .whenComplete(() => _active.remove(record.id));
    _active[record.id] = request;
    return request;
  }

  Future<CoachAdvice> _review(SetRecord record) async {
    final fallback = builtIn(record);
    if (!record.isCamera || record.reps.isEmpty) return fallback;
    try {
      final cached = await store.cachedAdvice(record.id);
      if (cached != null) return cached;
      final comparable = await store.recentComparable(record);
      final counts = _cueCounts(record);
      final candidates = counts.keys.isEmpty ? [Cue.repeat] : counts.keys;
      final evidence = <String, String>{
        'current':
            '${record.passed} of ${record.assessed} assessed reps passed the checks.',
        if (record.unassessed > 0)
          'framing':
              '${record.unassessed} completed reps couldn’t be assessed.',
        if (comparable.isNotEmpty &&
            comparable.first.assessed > 0 &&
            record.assessed > 0)
          'previous':
              'This set passed ${record.passed} of ${record.assessed} assessed reps. '
              'The previous comparable set passed ${comparable.first.passed} of ${comparable.first.assessed}.',
      };
      final prompt =
          'Choose one observation ID and one cue ID for the next workout set. '
          'Use a recorded alignment or depth cue when present, or reframe for missing evidence. '
          'Reply with exactly one JSON object with string keys observation and cue. '
          'Use IDs from the allowed lists. Do not add measurements or medical advice.\n'
          '${jsonEncode({
            'exercise': record.exercise.name,
            'passed': record.passed,
            'needsCorrection': record.needsCorrection,
            'unassessed': record.unassessed,
            'cueCounts': counts.map((cue, count) => MapEntry(cue.name, count)),
            'recentSimilarSets': [
              for (final set in comparable) {'passed': set.passed, 'assessed': set.assessed, 'unassessed': set.unassessed},
            ],
            'allowedObservationIds': evidence.keys.toList(),
            'allowedCueIds': candidates.map((cue) => cue.name).toList(),
          })}';
      final reply = await _generate(prompt)
          .timeout(const Duration(seconds: 18));
      final text = reply.text
          .trim()
          .replaceFirst(RegExp(r'^`{3}(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*`{3}$'), '');
      if (text.length > 600 || reply.source == CoachSource.builtIn) {
        return fallback;
      }
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic> || data.length != 2) return fallback;
      final observation = evidence[data['observation']];
      final cue = candidates
          .where((cue) => cue.name == data['cue'])
          .firstOrNull;
      if (observation == null || cue == null) return fallback;
      final advice = CoachAdvice(cue, observation, reply.source);
      await store.saveAdvice(record.id, advice);
      return advice;
    } on Exception {
      return fallback;
    }
  }

  static CoachAdvice builtIn(SetRecord record) {
    final counts = _cueCounts(record);
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cue = ranked.firstOrNull?.key ?? Cue.repeat;
    final observation = record.assessed == 0
        ? 'No reps had enough visible evidence for a form result.'
        : '${record.passed} of ${record.assessed} assessed reps passed the checks.';
    return CoachAdvice(cue, observation, CoachSource.builtIn);
  }

  static Map<Cue, int> _cueCounts(SetRecord record) {
    final counts = <Cue, int>{};
    for (final rep in record.reps) {
      final cue = rep.cue;
      if (cue != null) {
        counts.update(cue, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  static Future<CoachReply> _nativeGenerate(String prompt) async {
    final result = await _channel.invokeMapMethod<String, String>('generate', {
      'prompt': prompt,
      'cloudModel': _cloudModel,
    });
    final source = switch (result?['source']) {
      'onDevice' => CoachSource.onDevice,
      'cloud' => CoachSource.cloud,
      _ => throw const FormatException('Unrecognized inference source'),
    };
    return (text: result?['text'] ?? '', source: source);
  }
}
