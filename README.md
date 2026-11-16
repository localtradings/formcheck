# FormCheck

FormCheck is a camera-first Flutter workout coach for #BuildHybridAI 2026. It uses on-device MediaPipe pose tracking for squats and push-ups, a local gym log, and Firebase AI Logic hybrid inference for next-set coaching.

Android is the primary judging target. See [plan.md](plan.md) for the platform matrix, architecture, and release evidence, and [AGENTS.md](AGENTS.md) for project rules and reference sources.

[Devpost challenge](https://firebasehybridaihackathon.devpost.com/) · [Official rules](https://firebasehybridaihackathon.devpost.com/rules)

Project code is licensed under [Apache-2.0](LICENSE). Third-party notices apply to any components identified in the repository.

## Test the Android app

[Download the signed FormCheck 0.1.1 APK](https://github.com/localtradings/formcheck/raw/refs/heads/main/downloads/FormCheck-0.1.1-android-arm64.apk) on an ARM64 phone running Android 9 or later. Open the downloaded APK to install it.

## Build from source

1. Install Flutter **3.50.0** and use its bundled Dart. Android builds use the Android 36 SDK and the NDK version specified by Flutter, with JDK 21 recommended. iOS uses Xcode 26.2 or newer with Swift Package Manager. Simulator builds require Apple Silicon because the bundled MediaPipe runtime supplies an ARM64 simulator slice.
2. Run `flutter pub get` and `dart run mediapipe_core:bundle_models`. The MediaPipe tool downloads the pinned pose model and verifies its digest. The model is then bundled in the app for offline use.
3. Run `flutter analyze` and `flutter test`.
4. Run `flutter run` with a supported phone attached. The camera, workout history and built-in cues work with the downloaded model and without Firebase project credentials. Test camera framing and rep behavior on physical hardware.

To enable the hybrid coach, use a Firebase project with the Gemini Developer API, Firebase AI Logic and App Check enforcement. Register Android and iOS as `com.localtradings.formcheck`. Supply your team's Firebase client configurations at `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`. Both files are ignored. Use the debug provider only for development and keep all debug tokens private. See [Android hybrid setup](https://firebase.google.com/docs/ai-logic/hybrid/android/get-started), [iOS hybrid setup](https://firebase.google.com/docs/ai-logic/hybrid/ios/get-started) and [Firebase App Check](https://firebase.google.com/docs/ai-logic/app-check).

Android judging builds use Play Integrity and the private release signing configuration in `android/key.properties`. Register that signing certificate’s SHA-256 in Firebase. Use the documented Play Integrity settings for APKs distributed outside Google Play. Build with `flutter build apk --release --target-platform android-arm64 --split-per-abi`. The signed ARM64 APK is written to `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. On iOS, configure your Apple development team and App Attest. Apple SDK 12.19.2 is pinned because it contains the Firebase `HybridModel` API used here. [Play Integrity configuration](https://firebase.google.com/docs/app-check/android/play-integrity-provider) · [Apple SDK release notes](https://firebase.google.com/support/release-notes/ios)

Measure camera pipeline performance with `--dart-define=FORMCHECK_TIMINGS=true` in a profiling or release build and collect the aggregate timing logs. Run five minutes on the older Android test phone with its normal camera placement. Measurement uses camera frame receipt through the post-frame callback.
