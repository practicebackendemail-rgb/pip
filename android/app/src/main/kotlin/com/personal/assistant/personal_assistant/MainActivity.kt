package com.personal.assistant.personal_assistant

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.pip.companion/sfx"
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            // STREAM_MUSIC guarantees audio routes to phone speaker / media volume (level 11)
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Short cute robotic chirp when Pip starts talking
                "chirp" -> {
                    playPipChirp()
                    result.success(true)
                }
                // Double happy warble when Pip gives good news / finishes talking
                "happy" -> {
                    playPipHappy()
                    result.success(true)
                }
                // Inquisitive two-tone beep when Pip is thinking
                "thinking" -> {
                    playPipThinking()
                    result.success(true)
                }
                // Single mechanical typewriter blip
                "blip" -> {
                    playTone(ToneGenerator.TONE_PROP_BEEP, 35)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playTone(toneType: Int, durationMs: Int) {
        try {
            toneGenerator?.startTone(toneType, durationMs)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playPipChirp() {
        thread {
            playTone(ToneGenerator.TONE_PROP_PROMPT, 45)
            Thread.sleep(60)
            playTone(ToneGenerator.TONE_PROP_BEEP2, 55)
        }
    }

    private fun playPipHappy() {
        thread {
            playTone(ToneGenerator.TONE_PROP_BEEP, 40)
            Thread.sleep(70)
            playTone(ToneGenerator.TONE_PROP_PROMPT, 50)
            Thread.sleep(80)
            playTone(ToneGenerator.TONE_PROP_ACK, 70)
        }
    }

    private fun playPipThinking() {
        thread {
            playTone(ToneGenerator.TONE_SUP_RINGTONE, 80)
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
