package com.dosyaokuyucu.dosya_okuyucu

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * **Video küçültme — Media3 Transformer** (Faz 10, K2 (b)).
 *
 * FFmpeg (LGPL, ~15 MB) + `video_compress` yerine Android'in kendi donanım
 * kodlayıcısını süren Media3 Transformer (Apache 2.0, ~1-2 MB). Oynatıcı da
 * Media3 (ExoPlayer) olduğu için kodek kümesi tek.
 *
 * Kanal `dosya_okuyucu/transcode`:
 * - `probe(path)` → gösterim ölçüsü (döndürme uygulanmış), süre, kare hızı.
 * - `start(path, target, width, height, fps?, bitrate, removeAudio)` →
 *   bitince `done` / `failed` olayı; arada `progress` (0..100).
 * - `cancel()`.
 * Aynı anda tek iş (iş kuyruğu zaten sırayla veriyor).
 */
@OptIn(UnstableApi::class)
object MediaTranscodeBridge {
    private var channel: MethodChannel? = null
    private var transformer: Transformer? = null
    private val main = Handler(Looper.getMainLooper())

    fun configure(messenger: BinaryMessenger, context: Context) {
        val ch = MethodChannel(messenger, "dosya_okuyucu/transcode")
        channel = ch
        val app = context.applicationContext
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "probe" -> {
                    val path = call.argument<String>("path")
                    if (path == null) result.success(null) else {
                        // Disk okuması ana izleği tutmasın.
                        Thread {
                            val info = probe(path)
                            main.post { result.success(info) }
                        }.start()
                    }
                }
                "start" -> result.success(start(app, call.arguments as Map<*, *>))
                "cancel" -> {
                    transformer?.cancel()
                    transformer = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun probe(path: String): Map<String, Any>? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            var w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rot == 90 || rot == 270) { val t = w; w = h; h = t }
            val ms = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val out = mutableMapOf<String, Any>("width" to w, "height" to h, "durationMs" to ms)
            fps(path)?.let { out["fps"] = it }
            out
        } catch (e: Exception) {
            null
        } finally {
            try { r.release() } catch (e: Exception) {}
        }
    }

    private fun fps(path: String): Double? {
        val ex = MediaExtractor()
        return try {
            ex.setDataSource(path)
            (0 until ex.trackCount).map { ex.getTrackFormat(it) }
                .firstOrNull { it.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true }
                ?.takeIf { it.containsKey(MediaFormat.KEY_FRAME_RATE) }
                ?.let {
                    try { it.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble() }
                    catch (e: Exception) { it.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble() }
                }
        } catch (e: Exception) {
            null
        } finally {
            ex.release()
        }
    }

    private fun send(method: String, args: Any?) {
        main.post { try { channel?.invokeMethod(method, args) } catch (e: Exception) {} }
    }

    private fun start(context: Context, a: Map<*, *>): Boolean {
        val path = a["path"] as? String ?: return false
        val target = a["target"] as? String ?: return false
        val width = (a["width"] as? Number)?.toInt() ?: return false
        val height = (a["height"] as? Number)?.toInt() ?: return false
        val fps = (a["fps"] as? Number)?.toFloat()
        val bitrate = (a["bitrate"] as? Number)?.toInt() ?: 0
        val removeAudio = a["removeAudio"] == true
        transformer?.cancel()

        val videoEffects = mutableListOf<androidx.media3.common.Effect>(
            // Hedef ölçü Dart'ta orana göre hesaplandı; tam o ölçü üretilir.
            Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_STRETCH_TO_FIT)
        )
        if (fps != null && fps > 0) {
            videoEffects.add(FrameDropEffect.createDefaultFrameDropEffect(fps))
        }
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
            .setRemoveAudio(removeAudio)
            .setEffects(Effects(listOf(), videoEffects))
            .build()
        val settings = VideoEncoderSettings.Builder()
        if (bitrate > 0) settings.setBitrate(bitrate)
        val t = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(context)
                    .setRequestedVideoEncoderSettings(settings.build())
                    .setEnableFallback(true)
                    .build()
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    transformer = null
                    send("done", mapOf("target" to target))
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException
                ) {
                    transformer = null
                    File(target).delete()
                    send("failed", mapOf(
                        "code" to exportException.errorCodeName,
                        "message" to (exportException.message ?: "")
                    ))
                }
            })
            .build()
        transformer = t
        return try {
            t.start(item, target)
            pollProgress(t)
            true
        } catch (e: Exception) {
            transformer = null
            false
        }
    }

    private fun pollProgress(t: Transformer) {
        val holder = ProgressHolder()
        main.postDelayed(object : Runnable {
            override fun run() {
                if (transformer !== t) return
                if (t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    send("progress", holder.progress)
                }
                main.postDelayed(this, 500)
            }
        }, 500)
    }
}
