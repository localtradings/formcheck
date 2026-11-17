import 'package:mediapipe_core/mediapipe_core.dart';

/// Google's Full float16 Pose Landmarker, version 1. Shared with build setup.
const formCheckPoseModel = DownloadAsset(
  url:
      'https://storage.googleapis.com/mediapipe-models/pose_landmarker/'
      'pose_landmarker_full/float16/1/pose_landmarker_full.task',
  sha256: '5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1',
);
