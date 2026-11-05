package com.dosyaokuyucu.dosya_okuyucu

import android.app.Activity
import android.app.Presentation as DisplayPresentation
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.hardware.display.DisplayManager
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.KeyEvent
import android.widget.ImageView
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * **Slayt pro yerel köprüsü** (Faz 38) — `lib/services/pptx/pro/slides_native.dart`.
 * Kanal `dosya/slides`:
 *
 * - **video**(paths, durations, out, width, height) — slayt PNG'lerinden MP4
 *   (Media3 Transformer görüntü girdisi, donanım H.264; MediaTranscode ile
 *   aynı media3 1.5.1, yeni bağımlılık yok).
 * - **removeBg**(path, out) — ML Kit konu bölütleme (Play Hizmetleri modeli,
 *   APK'ya ~0 MB; ilk kullanımda iner → `downloading` hatası).
 * - **volumeKeys**(on) — sunum kumandası: ses tuşları `volume` olayı olur
 *   (MainActivity.dispatchKeyEvent buraya sorar).
 * - **recStart**(out) / **recStop** — slayt anlatımı (AAC/M4A).
 * - **screens** / **screenShow**(png) / **screenHide** — HDMI/Cast ikinci
 *   ekran (`Presentation`): slayt orada, notlar telefonda.
 */
@OptIn(UnstableApi::class)
class Slayt(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "dosya/slides"
    }

    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())
    private var transformer: Transformer? = null
    private var recorder: MediaRecorder? = null
    private var recPath: String? = null
    private var presentation: DisplayPresentation? = null
    private var screenImage: ImageView? = null
    var captureVolume = false
        private set

    private val displays: DisplayManager =
        activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = send("screens", presentationDisplays().size)
        override fun onDisplayRemoved(displayId: Int) {
            if (presentation?.display?.displayId == displayId) dismissScreen()
            send("screens", presentationDisplays().size)
        }
        override fun onDisplayChanged(displayId: Int) {}
    }

    fun attach(ch: MethodChannel) {
        channel = ch
        ch.setMethodCallHandler(this)
        displays.registerDisplayListener(displayListener, main)
    }

    fun dispose() {
        displays.unregisterDisplayListener(displayListener)
        transformer?.cancel()
        transformer = null
        stopRecorder()
        dismissScreen()
        captureVolume = false
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun send(method: String, args: Any?) {
        main.post { try { channel?.invokeMethod(method, args) } catch (e: Exception) {} }
    }

    /** MainActivity.dispatchKeyEvent'ten: tüketildiyse true. */
    fun onKey(event: KeyEvent): Boolean {
        if (!captureVolume) return false
        val code = event.keyCode
        if (code != KeyEvent.KEYCODE_VOLUME_UP && code != KeyEvent.KEYCODE_VOLUME_DOWN) return false
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            send("volume", if (code == KeyEvent.KEYCODE_VOLUME_DOWN) "next" else "prev")
        }
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "video" -> video(call, result)
            "cancelVideo" -> {
                transformer?.cancel()
                transformer = null
                result.success(true)
            }
            "removeBg" -> removeBg(call, result)
            "volumeKeys" -> {
                captureVolume = call.argument<Boolean>("on") == true
                result.success(true)
            }
            "recStart" -> recStart(call, result)
            "recStop" -> result.success(stopRecorder())
            "screens" -> result.success(presentationDisplays().size)
            "screenShow" -> screenShow(call, result)
            "screenHide" -> {
                dismissScreen()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // ── Video ─────────────────────────────────────────────────────────────

    private fun video(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths") ?: return result.error("args", "paths", null)
        val durations = call.argument<List<Number>>("durations") ?: emptyList()
        val out = call.argument<String>("out") ?: return result.error("args", "out", null)
        // H.264 kodlayıcıları çift ölçü ister.
        val width = ((call.argument<Number>("width")?.toInt() ?: 1920) / 2) * 2
        val height = ((call.argument<Number>("height")?.toInt() ?: 1080) / 2) * 2
        if (paths.isEmpty()) return result.error("args", "empty", null)
        transformer?.cancel()
        val effects = Effects(
            listOf(),
            listOf(Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT))
        )
        val items = paths.mapIndexed { i, p ->
            val ms = durations.getOrNull(i)?.toLong() ?: 5000L
            @Suppress("DEPRECATION")
            EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(p))))
                .setDurationUs(ms.coerceAtLeast(500L) * 1000L)
                .setFrameRate(30)
                .setEffects(effects)
                .build()
        }
        val composition = Composition.Builder(EditedMediaItemSequence(items)).build()
        var answered = false
        val t = Transformer.Builder(activity)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    transformer = null
                    if (!answered) { answered = true; result.success(out) }
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException
                ) {
                    transformer = null
                    File(out).delete()
                    if (!answered) {
                        answered = true
                        result.error(exportException.errorCodeName, exportException.message, null)
                    }
                }
            })
            .build()
        transformer = t
        try {
            t.start(composition, out)
        } catch (e: Exception) {
            transformer = null
            if (!answered) { answered = true; result.error("start", e.message, null) }
        }
    }

    // ── Arka plan kaldırma ────────────────────────────────────────────────

    private fun removeBg(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: return result.error("args", "path", null)
        val out = call.argument<String>("out") ?: return result.error("args", "out", null)
        val opts = BitmapFactory.Options().apply { inSampleSize = 1 }
        // Bellek tavanı: uzun kenar ≤ 2048 (anayasa k.4).
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var side = maxOf(bounds.outWidth, bounds.outHeight)
        while (side > 2048) { opts.inSampleSize *= 2; side /= 2 }
        val bmp = BitmapFactory.decodeFile(path, opts) ?: return result.error("decode", path, null)
        val client = SubjectSegmentation.getClient(
            SubjectSegmenterOptions.Builder().enableForegroundBitmap().build()
        )
        client.process(InputImage.fromBitmap(bmp, 0))
            .addOnSuccessListener { r ->
                val fg = r.foregroundBitmap
                if (fg == null) {
                    result.error("empty", "no subject", null)
                } else {
                    Thread {
                        try {
                            FileOutputStream(out).use { fg.compress(Bitmap.CompressFormat.PNG, 100, it) }
                            main.post { result.success(out) }
                        } catch (e: Exception) {
                            main.post { result.error("write", e.message, null) }
                        }
                    }.start()
                }
                client.close()
            }
            .addOnFailureListener { e ->
                client.close()
                val msg = e.message ?: ""
                result.error(if (msg.contains("download", true) || msg.contains("module", true)) "downloading" else "failed", msg, null)
            }
    }

    // ── Anlatım kaydı ─────────────────────────────────────────────────────

    private fun recStart(call: MethodCall, result: MethodChannel.Result) {
        val out = call.argument<String>("out") ?: return result.error("args", "out", null)
        stopRecorder()
        try {
            @Suppress("DEPRECATION")
            val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(activity) else MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(96000)
            r.setAudioSamplingRate(44100)
            r.setOutputFile(out)
            r.prepare()
            r.start()
            recorder = r
            recPath = out
            result.success(true)
        } catch (e: Exception) {
            recorder = null
            recPath = null
            result.error("rec", e.message, null)
        }
    }

    private fun stopRecorder(): String? {
        val r = recorder ?: return null
        val p = recPath
        recorder = null
        recPath = null
        return try {
            r.stop()
            r.release()
            p
        } catch (e: Exception) {
            // Çok kısa kayıt (veri yok) stop'ta hata verir: dosya geçersiz.
            r.release()
            p?.let { File(it).delete() }
            null
        }
    }

    // ── İkinci ekran ──────────────────────────────────────────────────────

    private fun presentationDisplays(): Array<Display> =
        displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)

    private fun screenShow(call: MethodCall, result: MethodChannel.Result) {
        val png = call.argument<ByteArray>("png") ?: return result.error("args", "png", null)
        val display = presentationDisplays().firstOrNull() ?: return result.success(false)
        val bmp = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return result.success(false)
        var p = presentation
        if (p == null || p.display?.displayId != display.displayId) {
            dismissScreen()
            val view = ImageView(activity).apply {
                scaleType = ImageView.ScaleType.FIT_CENTER
                setBackgroundColor(android.graphics.Color.BLACK)
            }
            p = object : DisplayPresentation(activity, display) {
                override fun onCreate(savedInstanceState: Bundle?) {
                    super.onCreate(savedInstanceState)
                    setContentView(view)
                }
            }
            screenImage = view
            presentation = p
            try {
                p.show()
            } catch (e: Exception) {
                presentation = null
                screenImage = null
                return result.success(false)
            }
        }
        screenImage?.setImageBitmap(bmp)
        result.success(true)
    }

    private fun dismissScreen() {
        try { presentation?.dismiss() } catch (e: Exception) {}
        presentation = null
        screenImage = null
    }
}
