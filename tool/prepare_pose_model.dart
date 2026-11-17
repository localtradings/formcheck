import 'dart:convert';
import 'dart:io';

import 'package:mediapipe_core/mediapipe_core.dart';

import 'package:formcheck/application/pose_model.dart';

Future<void> main() async {
  final model = formCheckPoseModel;
  final verified = await ModelStore(
    cacheDirectory: '.dart_tool/formcheck_models',
  ).get(model);
  final directory = Directory('assets/mediapipe');
  await directory.create(recursive: true);
  await File(verified.path!).copy('${directory.path}/${model.sha256}');
  for (final notice in ['LICENSE', 'NOTICE']) {
    await File(notice).copy('${directory.path}/$notice');
  }
  await File('${directory.path}/manifest.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'note': 'Prepared and SHA-256 verified by dart run tool/prepare_pose_model.dart.',
      'models': [
        {
          'model': 'FormCheck Pose Full v1',
          'file': model.sha256,
          'url': model.url,
        },
      ],
    }),
  );
  // Remove only the previous generated Lite bundle, which the app no longer uses.
  final lite = File(
    '${directory.path}/59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a',
  );
  if (await lite.exists()) await lite.delete();
  stdout.writeln(
    'Bundled Google Pose Full v1; verified SHA-256 ${model.sha256}.',
  );
}
