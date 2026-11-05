package com.dosyaokuyucu.dosya_okuyucu

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * **Sesle yazma** (Faz 37 madde 6) — `lib/services/dictation.dart`taki
 * `Dictation`ın Kotlin yüzü. Kanal `dosya/dictate`, tek iş:
 *
 * **start** — cihazın konuşma tanıyıcısı (`RecognizerIntent`, çoğunlukla
 * Google uygulaması; çevrimdışı dil paketi varsa internetsiz). Mikrofon izni
 * tanıyıcı uygulamada; bizim uygulamaya RECORD_AUDIO EKLENMEZ. Dönüş: en iyi
 * sonuç metni (vazgeçilirse null). Tanıyıcı yoksa `unavailable`.
 */
class Dikte(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "dosya/dictate"
        const val REQ_DICTATE = 7361
    }

    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call.argument<String>("lang"), call.argument<String>("prompt"), result)
            "available" -> result.success(
                RecognizerIntent.ACTION_RECOGNIZE_SPEECH.let {
                    Intent(it).resolveActivity(activity.packageManager) != null
                })
            else -> result.notImplemented()
        }
    }

    private fun start(lang: String?, prompt: String?, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Dikte zaten açık", null)
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            if (!lang.isNullOrEmpty()) putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            if (!prompt.isNullOrEmpty()) putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        try {
            pending = result
            activity.startActivityForResult(intent, REQ_DICTATE)
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.error("unavailable", e.message, null)
        }
    }

    fun handleResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_DICTATE) return false
        val r = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            r.success(null)
            return true
        }
        val list = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
        r.success(list?.firstOrNull())
        return true
    }
}
