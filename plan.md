# FormCheck system design

## Product and targets

FormCheck uses a phone camera for side-view bodyweight squats and floor push-ups. A user checks framing, performs a set, sees measured rep results and one coaching cue, and can retry or look up the set in Progress. Gym offers a starter routine and manual sets with reps and optional weight.

| Target | Scope | Acceptance |
| --- | --- | --- |
| Android 9+ | Primary judging build. MediaPipe and SQLite offline. Gemini Nano 4 on eligible phones with Gemini cloud fallback. | Physical Nano 4 phone, older supported phone, and fresh signed APK install. |
| iOS 15+ | Shared core with compatible hardware. Apple Foundation Models on eligible phones with Gemini cloud fallback. | Eligible and older physical iPhones. External TestFlight access required to include iOS on Devpost. |
| Web, desktop, wearables, stores | Outside current submission scope. | No release claim. |

## System design

- Flutter and Dart with Riverpod. Pin a tested Flutter release of 3.47 or above and commit resolved dependency locks. Android uses Kotlin for Firebase and iOS uses Swift.
- The Flutter camera streams frames to MediaPipe Pose Landmarker using its bundled model and CPU delegate. Use a replaceable pose adapter, monotonic timestamps, bounded frame conversion and inference, correct sensor orientation and preview mapping, and a camera-session generation to drop stale results. Stop capture on foreground exit. Check older-device CPU performance before release.
- A pure Dart engine consumes timestamped image and world landmarks with confidence and frame geometry. Require a side-view starting pose and one clearly tracked subject. Choose the visible side before the movement and hold it through completion. Smooth the primary joint angle, use hysteresis and sustained top and motion states, and close each rep only after a return to top. Use hip–knee–ankle for squat depth and shoulder–elbow–wrist plus shoulder–hip–ankle alignment for push-ups. Preserve a separate threshold for movement detection so a shallow completed rep still counts. Track passed, needs correction, and could not assess. A lost primary trajectory resets the unfinished movement. Insufficient evidence for a form check on a completed movement yields could not assess. Store the profile and rule version and validate provisional thresholds with labeled footage.
- Use one live cue at a time with a repeat cooldown and optional locally bundled voice. Text and semantics convey status without relying on color or sound. Maintain keyboard and screen reader focus, safe areas, text scaling, and reduced-motion equivalents.
- Drift and SQLite store session ID and timestamps, set ID and exercise, source, profile and version, and individual rep outcomes and cue IDs. Manual sets hold reps and optional weight. Save each set and its reps in one idempotent transaction. Progress queries compare like profiles and show passed divided by assessed reps. Include unassessed separately and keep manual sets out of the form rate. Use explicit local deletion and exclude private history from OS backup.
- After saving, offer an explicit set review with disclosure. The typed coach bridge submits bounded aggregate counts, allowed cue IDs, and comparable recent counts to Firebase AI Logic. Android uses local-first hybrid inference with Gemini Nano 4 when available. Apple uses the system model as primary and cloud as secondary. The configured Gemini Developer API cloud model starts at `gemini-3.8-flash`. Validate the selected observation and cue IDs against measured results, then render approved copy. Use the SDK response to distinguish device and cloud. Keep a built-in fallback, reuse successful reviews, and bound concurrent requests and timeouts. No images, audio, raw landmarks, or identifying details enter review requests.
- Separate dev from judging Firebase. Enable App Check enforcement, use release attestation and private debug enrollment, and keep signing and service credentials out of the repository. Keep rates bounded and verify model availability and actual quotas. At 10% daily actives, two reviews per active, and 50% cloud fallback, 500,000 and 2 million registrations imply 50,000 and 200,000 cloud requests per day. These are untested planning scenarios. Record privacy-safe performance and error summaries, check billing before enabling it, and revert a bad build via the prior signed release.

[MediaPipe for Flutter](https://developers.google.com/edge/mediapipe/solutions/setup_flutter) · [Android hybrid](https://firebase.google.com/docs/ai-logic/hybrid/android/get-started) · [iOS hybrid](https://firebase.google.com/docs/ai-logic/hybrid/ios/get-started) · [Firebase models](https://firebase.google.com/docs/ai-logic/models) · [Quotas](https://firebase.google.com/docs/ai-logic/quotas)

## Source findings and provenance

| Reference | Planned use |
| --- | --- |
| [Flutter MediaPipe](https://github.com/google/flutter-mediapipe) and [native samples](https://github.com/google-ai-edge/mediapipe-samples) | Apache-2.0 starter patterns for live camera, orientation, preview, lifecycle and landmark conversion. |
| [FitnessPipe](https://github.com/jinzishuai/fitnessPipe/tree/425b4c073d9a42885b3e6671bae8c91377e97e0a) | MIT Dart counters, smoothing and feedback cooldown reference. Uses Google ML Kit in its camera adapter. |
| [IO_motion](https://github.com/bardia1122/IO_motion/tree/4dc82b852abb6f0b7fdc8b45d90f1fb563d89340) | Source shows separate squat and push-up analyzers and documents poor far-leg estimates on side views. Reference only, no source license identified. |
| [FitSense Capstone](https://github.com/jeyaye/Fitsense-Capstone-Project/tree/d4291be49e19aa6fa63c1096587b7c4e31cc02c9) | Source shows a four-phase rep counter. Reference only, no source license identified. |
| [Motion Form Feedback](https://github.com/gulingguinxling-del/Motion-Form-Feedback/tree/ce9389d39d0803cc7289012e8240126404c393bc) | README describes sequence coaching. Runtime unverified and no source license identified. |
| [openGym](https://github.com/DuarteSantos8/openGym/tree/e4a68a94c42a3c17cbd560d66ce2e46a7048ab99) | AGPL routine and history reference. Separate rights apply to exercise media. |
| [Flexify](https://github.com/brandonp2412/flexify/tree/eacfe87e28018361f86f90a52e8b3cb3e34e5e76) | Additional MIT Flutter and Drift reference for storing sets and querying exercise history. |
| [Exercises Dataset](https://github.com/hasaneyldrm/exercises-dataset) | Optional licensed exercise text and metadata. Publish original demo media. Use consenting team footage locally and synthetic landmark fixtures for committed tests. |
| [Firebase Android quickstart](https://github.com/firebase/quickstart-android/tree/master/firebase-ai) | Official hybrid receipt example for model preference and source reporting. |

Evidence here is source-level. Binary review of authorized APKs with REA and Ghidra is available if an unresolved behavioral question warrants it. See [AGENTS.md](AGENTS.md) for all references and tool rules.

## Acceptance and submission

- **Nov 17–19, Manila.** Publish the public licensed repo and planning files. Verify live pose and Firebase hybrid inference on physical Android hardware. Start iPhone signing and builds.
- **Nov 20–25.** Verify end-to-end workout flow. Replay correct and shallow reps, hip drift, incomplete movements, noise, occlusion and tracker loss. Test duplicate saves, restart, manual sets, progress, deletion and invalid model replies.
- **Nov 26–29.** Verify signed fresh-install build, camera permissions and resume, both cameras, App Check, offline fallback, big text, reduced motion and hardware coverage. Target 10 analyzed frames per second and p95 under 300 ms frame to overlay on the older Android test device over five minutes. Record measured results and gaps. Release attestation needs the actual distribution configuration.
- **Devpost.** Submit by Nov 29 for buffer. Official deadline is Dec 1, 2026 at 6:00 a.m. Manila. Public GitHub or GitLab source with detectable open-source license, reproducible setup, working free judge build, public YouTube demo of at most three minutes in English or with English subtitles, a summary of original and reused work, clear Firebase AI Logic use, all eligible team members, and a designated representative. Keep judging access through Dec 17, 2026 at 6:00 a.m. Manila.
- **Demo sequence.** Show both exercises and all three outcomes, the coach next-set cue, a retry, and the Progress entry. Show actual on-device generation and actual cloud fallback with source labels. Keep the signing and service credentials private.

[Devpost challenge](https://firebasehybridaihackathon.devpost.com/) · [Official rules](https://firebasehybridaihackathon.devpost.com/rules)

## Current evidence

Planning and public-source review completed. Phone camera, model generation, signing, and judging access require verification. No physical Android device was attached at kickoff.

### Implementation decisions made during the build

- The application uses Flutter 3.50.0 and MediaPipe Vision 0.3.0. The model bundle is downloaded with the package's pinned digest. Android uses Firebase AI Logic 18.2.0 and the companion on-device SDK 16.0.0-beta08. iOS uses the Swift Package Manager release 12.19.2 because the later major release removed the `HybridModel` API used by the submission design.
- The initial rep rules are deliberately provisional. The squat profile starts at 153° for standing, 128° for a completed movement candidate and 105° for depth. The push-up profile starts at 151°, 127°, and 100° respectively, with 155° for shoulder–hip–ankle alignment. Pixel-aspect correction is applied to the 2D measurements. Use consented clips on physical phones to calibrate these values before judging. A failed target corresponds to the measured check in the selected camera view.
- The optional audio cues use installed system voices. Android selects only an installed English voice that requires no network. The cue and its form result remain visible in text.
- The judging Firebase project has both mobile apps registered. The Android release certificate SHA-256 is registered, AI Logic App Check enforcement is enabled, and Play Integrity is configured for an APK distributed outside Google Play. Actual signed device attestation and model inference are distinct acceptance gates.
- Reused source is limited to the camera frame conversion and camera geometry patterns from Google's Apache-2.0 [Flutter MediaPipe gallery](https://github.com/google/flutter-mediapipe/tree/672687c6ae517c1a8791677c88c9f73eaa94d575/gallery/lib/live). The [Firebase Android example](https://github.com/firebase/quickstart-android/tree/153d77572e27715fae8e94269debefb5c25507b8/firebase-ai) informed the native inference adapter. FormCheck's state machine, storage, UI, prompt contract and workout flow were built for this entry. No third-party workout footage or artwork is bundled.
