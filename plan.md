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
- Use one live cue at a time with a repeat cooldown and optional offline voice. Text and semantics convey status without relying on color or sound. Maintain keyboard and screen reader focus, safe areas, text scaling, and reduced-motion equivalents.
- Drift and SQLite store session ID and timestamps, set ID and exercise, source, profile and version, and individual rep outcomes and cue IDs. Manual sets hold reps and optional weight. Save each set and its reps in one idempotent transaction. Progress queries compare like profiles and show passed divided by assessed reps. Include unassessed separately and keep manual sets out of the form rate. Use explicit local deletion and exclude private history from OS backup.
- After saving, offer an explicit set review with disclosure. The typed coach bridge submits bounded aggregate counts, allowed cue IDs, and comparable recent counts to Firebase AI Logic. Android uses local-first hybrid inference with Gemini Nano 4 when available. Apple uses the system model as primary and cloud as secondary when the system model is available. Phones without the system model use the Firebase cloud path directly. The Gemini Developer API cloud model is `gemini-3.5-flash-lite`. Validate the selected observation and cue IDs against measured results, then render approved copy. Use the SDK response to distinguish device and cloud. Keep a built-in fallback, reuse successful reviews, and bound concurrent requests and timeouts. No images, audio, raw landmarks, or identifying details enter review requests.
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

## Devpost draft

FormCheck is a phone camera coach for bodyweight squats and push-ups. It counts completed reps, flags the form checks that need attention, and tells you when it needs a clearer view. A local history shows progress across comparable sets. Gym also offers a starter routine and manual logging.

MediaPipe reads the camera on the phone. When you request a next-set review, Firebase AI Logic receives the rep totals and observed cue IDs so it can prioritize one correction. The Android coach tries Gemini Nano on eligible devices and can use Gemini in the cloud with your permission. The app displays where the response came from and can offer a built-in cue if generation is unavailable.

For this entry the team built the Flutter workflow, rep and cue rules, local workout log, and hybrid coaching integration. The camera integration adapts Google's Apache-licensed Flutter MediaPipe example. See [source findings and provenance](#source-findings-and-provenance) for the upstream references.

| Demo time | Show |
| --- | --- |
| 0:00–0:20 | Introduce the problem and set up the phone for a side view. |
| 0:20–0:55 | Show a squat that passes, a shallow squat, and the reposition message during lost tracking. |
| 0:55–1:25 | Show a push-up alignment cue and a completed push-up marked Couldn’t assess when an alignment landmark is obscured. Show the three counts. |
| 1:25–2:10 | Request coaching, capture the actual on-device source label, retry and show the saved sets in Progress. |
| 2:10–2:50 | Make a review on the older Android phone and capture the actual cloud source label. Briefly show Gym and the public source link. |

## Current evidence

The repository is public, its default branch is `main`, and GitHub detects the Apache-2.0 license. The Flutter app implements the camera, rep analysis, coaching, Gym and Progress flows. Release acceptance is recorded below.

| Check | Evidence as of Nov 17, 2026 (Manila) |
| --- | --- |
| Dart analysis and automated tests | Local clean analysis and nine passing tests. Coverage includes noisy or interrupted reps, second-person rejection, push-up alignment, unassessed reps, idempotent local storage, progress, deletion, coach output validation and caching, permission dialog focus changes, and a 320 × 640 layout at 2× text. |
| Android build without project credentials | GitHub Actions compiled a clean debug APK on Ubuntu using the locked SDK and dependencies. [Successful Android job](https://github.com/localtradings/formcheck/actions/runs/43939209379/job/133551878702) |
| Android release build | Version 0.1.1 is signed for ARM64. Package `com.localtradings.formcheck` targets API 36 with minimum API 28. The signing certificate matches the Firebase registration. Verified the bundled MediaPipe library and pinned pose-model digest. APK SHA-256 `ce06b6b02dac12b52745a3185a335a3fcdfd8f859672e7b2ffd6f58b4a375b9d`. |
| Android emulator | Fresh install of the signed 0.1.0 APK on Android 15 ARM64. While offline, a single permission denial showed a recovery message, explicit retry opened the camera, both virtual lenses opened with MediaPipe's CPU runtime, and a manual set survived a process restart. An offline set logged on 0.1.0 also appeared in Progress after installing the signed 0.1.1 update. |
| Firebase App Check | Enforcement is on. A live request to the judging project's Gemini Developer API route without an App Check token returned HTTP 401 and identified App Check as the reason. A separate development app with App Check enforcement used a temporary emulator enrollment. Firebase selected the cloud for a synthetic push-up set and FormCheck validated and stored the returned cue. Release attestation and inference on the judging phones remain pending. [Firebase AI Logic setup](https://firebase.google.com/docs/ai-logic/get-started) |
| Android physical phones | Pending. Verify camera tracking and rule calibration, placement and mirroring, Play Integrity, Nano 4 and cloud results, offline fallback, and the five-minute performance targets on the two planned devices. |
| iOS | Xcode 26.6 built the ARM64 simulator app with minimum iOS 15. The iPhone 17 simulator opened the Camera tab. A development build using the final iOS bridge saved a validated Foundation Models cue, and a separate test of the direct cloud path saved a Gemini cue with App Check enforced. The judging project still needs the intended Apple Developer Team ID for App Attest. Signed physical-phone checks, release attestation and external TestFlight acceptance are pending. |
| Judging and distribution | The v0.1.1 GitHub release draft exists. GitHub returned HTTP 408 before the signed APK upload completed. The verified APK is available locally. Judging still requires signed hardware runs, an accessible judge download, the team demo recording, the Devpost team roster and final submission. Include iOS only after its device and external TestFlight checks pass. |

### Implementation decisions made during the build

- The application uses Flutter 3.50.0 and MediaPipe Vision 0.3.0. The model bundle is downloaded with the package's pinned digest. Android uses Firebase AI Logic 18.2.0 and the companion on-device SDK 16.0.0-beta08. iOS uses the Swift Package Manager release 12.19.2 because the later major release removed the `HybridModel` API used by the submission design.
- Gemini 3.8 Flash timed out in development through the Android SDK and in a direct Firebase AI Logic request with low thinking. Gemini 3.5 Flash-Lite returned a live response through the Android hybrid adapter and passed FormCheck’s cue validation. The release candidate uses Flash-Lite on both platforms and retains its device-first configuration. Temporary development App Check enrollment was revoked. [Firebase AI Logic thinking options](https://firebase.google.com/docs/ai-logic/thinking)
- The iOS Runner target defines `DEBUG` for Debug builds so a development simulator can use a registered debug App Check token. Release uses App Attest. The app checks Apple system model availability before creating the Firebase hybrid session. Temporary iOS development enrollments were revoked after verification. [Firebase App Check for Apple development](https://firebase.google.com/docs/app-check/ios/debug-provider)
- The initial rep rules are deliberately provisional. The squat profile starts at 153° for standing, 128° for a completed movement candidate and 105° for depth. The push-up profile starts at 151°, 127°, and 100° respectively, with 155° for shoulder–hip–ankle alignment. Pixel-aspect correction is applied to the 2D measurements. Use consented clips on physical phones to calibrate these values before judging. A failed target corresponds to the measured check in the selected camera view.
- The optional audio cues use installed system voices. Android selects only an installed English voice that requires no network. The cue and its form result remain visible in text.
- The judging Firebase project has both mobile apps registered. The Android release certificate SHA-256 is registered, AI Logic App Check enforcement is enabled, and Play Integrity is configured for an APK distributed outside Google Play. Actual signed device attestation and model inference are distinct acceptance gates.
- Reused source is limited to the camera frame conversion and camera geometry patterns from Google's Apache-2.0 [Flutter MediaPipe gallery](https://github.com/google/flutter-mediapipe/tree/672687c6ae517c1a8791677c88c9f73eaa94d575/gallery/lib/live). The [Firebase Android example](https://github.com/firebase/quickstart-android/tree/153d77572e27715fae8e94269debefb5c25507b8/firebase-ai) informed the native inference adapter. FormCheck's state machine, storage, UI, prompt contract and workout flow were built for this entry. No third-party workout footage or artwork is bundled.
