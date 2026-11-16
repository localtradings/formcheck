import AVFoundation
import FirebaseAILogic
import FirebaseAppCheck
import FirebaseCore
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let cloudModel = "gemini-3.5-flash-lite"
  private let voice = AVSpeechSynthesizer()
  private var reviewInFlight = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
      #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
      #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
      #endif
      FirebaseApp.configure()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterMethodChannel(name: "formcheck/coach", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "generate" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let self, let data = call.arguments as? [String: String],
              let prompt = data["prompt"], !prompt.isEmpty, prompt.count <= 4500,
              data["cloudModel"] == Self.cloudModel,
              FirebaseApp.app() != nil, !self.reviewInFlight else {
          result(Self.unavailable())
          return
        }
        self.generate(prompt, result)
      }
    FlutterMethodChannel(name: "formcheck/device", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "settings":
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
          result(nil)
        case "speak":
          if let message = call.arguments as? String, message.count <= 100,
             let speaker = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "en-US" }) {
            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = speaker
            self?.voice.stopSpeaking(at: .immediate)
            self?.voice.speak(utterance)
          }
          result(nil)
        case "stopVoice":
          self?.voice.stopSpeaking(at: .immediate)
          result(nil)
        case "excludeBackup":
          guard let path = call.arguments as? String else {
            result(FlutterError(code: "LOCAL_STORAGE", message: "Missing storage directory.", details: nil))
            return
          }
          do {
            var directory = URL(fileURLWithPath: path, isDirectory: true)
            var restrictions = URLResourceValues()
            restrictions.isExcludedFromBackup = true
            try directory.setResourceValues(restrictions)
            result(nil)
          } catch {
            result(FlutterError(code: "LOCAL_STORAGE", message: "Could not protect local history from backup.", details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  private func generate(_ prompt: String, _ result: @escaping FlutterResult) {
    reviewInFlight = true
    Task { @MainActor in
      defer { reviewInFlight = false }
      do {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI(), useLimitedUseAppCheckTokens: true)
        if #available(iOS 26.0, *) {
          let cloud = ai.geminiModel(name: Self.cloudModel)
          let session = ai.generativeModelSession(
            model: .hybridModel(primary: FirebaseAI.SystemLanguageModel.default, secondary: cloud)
          )
          let response = try await session.respond(to: prompt)
          let version = response.rawResponse.modelVersion
          switch version {
          case "apple-foundation-models-system-language-model":
            result(["text": response.content, "source": "onDevice"])
          case let version where version.hasPrefix("gemini-"):
            result(["text": response.content, "source": "cloud"])
          default:
            result(Self.unavailable())
          }
        } else {
          let response = try await ai.generativeModel(modelName: Self.cloudModel)
            .generateContent(prompt)
          if let text = response.text {
            result(["text": text, "source": "cloud"])
          } else {
            result(Self.unavailable())
          }
        }
      } catch {
        result(Self.unavailable())
      }
    }
  }

  private static func unavailable() -> FlutterError {
    FlutterError(code: "COACH_UNAVAILABLE", message: "The built-in cue is available.", details: nil)
  }
}
