package com.localtradings.formcheck

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.speech.tts.TextToSpeech
import com.google.firebase.Firebase
import com.google.firebase.FirebaseApp
import com.google.firebase.ai.ai
import com.google.firebase.ai.type.GenerativeBackend
import com.google.firebase.ai.type.InferenceMode
import com.google.firebase.ai.type.InferenceSource
import com.google.firebase.ai.type.OnDeviceConfig
import com.google.firebase.ai.type.OnDeviceModelOption
import com.google.firebase.ai.type.PublicPreviewAPI
import com.google.firebase.appcheck.FirebaseAppCheck
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var tts: TextToSpeech? = null
    private var speechReady = false
    private var reviewInFlight = false

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        // A build without local Firebase config can still run the offline workout.
        val firebaseReady = FirebaseApp.initializeApp(applicationContext) != null
        if (firebaseReady) {
            FirebaseAppCheck.getInstance().installAppCheckProviderFactory(coachAppCheck())
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "formcheck/coach")
            .setMethodCallHandler { call, result ->
                if (call.method != "generate") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val prompt = call.argument<String>("prompt")
                val model = call.argument<String>("cloudModel")
                if (!firebaseReady || prompt.isNullOrBlank() || prompt.length > 4500 ||
                    model != "gemini-3.8-flash" || reviewInFlight) {
                    result.error("COACH_UNAVAILABLE", "The built-in cue is available.", null)
                    return@setMethodCallHandler
                }
                generate(prompt, model, result)
            }
        MethodChannel(engine.dartExecutor.binaryMessenger, "formcheck/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "settings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null)))
                        result.success(null)
                    }
                    "speak" -> {
                        (call.arguments as? String)?.take(100)?.let(::speak)
                        result.success(null)
                    }
                    "stopVoice" -> {
                        tts?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @OptIn(PublicPreviewAPI::class)
    private fun generate(prompt: String, model: String, result: MethodChannel.Result) {
        reviewInFlight = true
        scope.launch {
            try {
                val engine = Firebase.ai(
                    backend = GenerativeBackend.googleAI(),
                    useLimitedUseAppCheckTokens = true,
                ).generativeModel(
                    modelName = model,
                    onDeviceConfig = OnDeviceConfig(
                        mode = InferenceMode.PREFER_ON_DEVICE,
                        modelOption = OnDeviceModelOption.PREVIEW_FAST,
                    ),
                )
                val response = withTimeoutOrNull(16_000) { engine.generateContent(prompt) }
                val text = response?.text
                val source = when (response?.inferenceSource) {
                    InferenceSource.ON_DEVICE -> "onDevice"
                    InferenceSource.IN_CLOUD -> "cloud"
                    else -> null
                }
                if (text == null || source == null) {
                    result.error("COACH_UNAVAILABLE", "The built-in cue is available.", null)
                } else {
                    result.success(mapOf("text" to text, "source" to source))
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                result.error("COACH_UNAVAILABLE", "The built-in cue is available.", null)
            } finally {
                reviewInFlight = false
            }
        }
    }

    private fun speak(message: String) {
        val current = tts
        if (current == null) {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    val engine = tts ?: return@TextToSpeech
                    val voice = engine.voices?.firstOrNull {
                        it.locale.language == "en" && !it.isNetworkConnectionRequired &&
                            it.features?.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) != true
                    }
                    if (voice != null) {
                        engine.voice = voice
                        speechReady = true
                    }
                }
            }
            return
        }
        if (speechReady) current.speak(message, TextToSpeech.QUEUE_FLUSH, null, "formcheck-cue")
    }

    override fun onStop() {
        tts?.stop()
        super.onStop()
    }

    override fun onDestroy() {
        scope.cancel()
        tts?.shutdown()
        super.onDestroy()
    }
}
