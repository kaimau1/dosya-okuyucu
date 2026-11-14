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
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
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
 * - `start(path, target, width, height, fps?, bitrate, removeAudio, layout?)` →
 *   bitince `done` / `failed` olayı; arada `progress` (0..100).
 * - `trim(path, target, startMs, endMs, removeAudio)` → aralığı kesip yazar
 *   (aynı `done` / `failed` / `progress` olayları).
 * - `edit(path, target, pieces, audio, removeAudio)` → çok parçalı düzenleme:
 *   aradan silinen bölümler, sessiz bölgeler, bölgeye eklenen ses.
 * - `frames(path, count, width, dir)` → kes ekranının kare şeridi.
 * - `frame(path, ms, target, rotation)` → o anki kare tam çözünürlükte JPEG.
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
                // Video kesme (Ferrari H8, 2026-11-14): aralık dışı atılır,
                // özgün korunur; mümkünse yeniden kodlamasız (trim optimizasyonu).
                "trim" -> result.success(trim(app, call.arguments as Map<*, *>))
                // Video düzenleme (2026-11-14): çok parçalı kesim + ses bölgeleri.
                "edit" -> result.success(edit(app, call.arguments as Map<*, *>))
                // Kes ekranının kare şeridi: eşit aralıklı N kare → JPEG yolları.
                "frames" -> {
                    val a = call.arguments as Map<*, *>
                    Thread {
                        val out = frames(a)
                        main.post { result.success(out) }
                    }.start()
                }
                // Kareyi fotoğraf kaydet (Ferrari H8.5): tek kare → JPEG.
                "frame" -> {
                    val a = call.arguments as Map<*, *>
                    Thread {
                        val ok = frame(a)
                        main.post { result.success(ok) }
                    }.start()
                }
                // Sesli kitap (2026-10-22): üretilen WAV → AAC/M4A (~10 kat küçük).
                "startAudio" -> result.success(startAudio(app, call.arguments as Map<*, *>))
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
        // Faz 14b: kutuya yerleşim — Dart `VideoLayout` adı. "fit" = oran
        // korunur + siyah şerit, "crop" = doldur + ortadan kırp, diğeri esnet
        // (hedef zaten kaynağın oranındaysa bozulma olmaz).
        val layout = when (a["layout"] as? String) {
            "fit" -> Presentation.LAYOUT_SCALE_TO_FIT
            "crop" -> Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP
            else -> Presentation.LAYOUT_STRETCH_TO_FIT
        }
        transformer?.cancel()

        val videoEffects = mutableListOf<androidx.media3.common.Effect>(
            // Hedef ölçü Dart'ta hesaplandı; tam o ölçü üretilir.
            Presentation.createForWidthAndHeight(width, height, layout)
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

    private fun startAudio(context: Context, a: Map<*, *>): Boolean {
        val path = a["path"] as? String ?: return false
        val target = a["target"] as? String ?: return false
        transformer?.cancel()
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
            .setRemoveVideo(true)
            .build()
        val t = Transformer.Builder(context)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
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

    /** İşin bitiş/hata olayları (yarım çıktı silinir). */
    private fun exportListener(target: String) = object : Transformer.Listener {
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
    }

    /**
     * `trim(path, target, startMs, endMs, removeAudio)` — yalnız aralık kalır.
     * Efekt yok: döndürme bilgisi kaynaktaki gibi taşınır (küçültmedeki
     * dikey→yatay tuzağı burada yok). Trim optimizasyonu baştaki yarım GOP'u
     * kodlar, gerisini olduğu gibi kopyalar; uygun değilse Transformer
     * kendiliğinden tam kodlamaya döner.
     */
    private fun trim(context: Context, a: Map<*, *>): Boolean {
        val path = a["path"] as? String ?: return false
        val target = a["target"] as? String ?: return false
        val startMs = (a["startMs"] as? Number)?.toLong() ?: return false
        val endMs = (a["endMs"] as? Number)?.toLong() ?: return false
        if (startMs < 0 || endMs <= startMs) return false
        val removeAudio = a["removeAudio"] == true
        transformer?.cancel()
        val clip = MediaItem.ClippingConfiguration.Builder()
            .setStartPositionMs(startMs)
            .setEndPositionMs(endMs)
            .build()
        val media = MediaItem.Builder()
            .setUri(Uri.fromFile(File(path)))
            .setClippingConfiguration(clip)
            .build()
        val item = EditedMediaItem.Builder(media)
            .setRemoveAudio(removeAudio)
            .build()
        val t = Transformer.Builder(context)
            .experimentalSetTrimOptimizationEnabled(!removeAudio)
            .addListener(exportListener(target))
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

    /**
     * `edit(path, target, pieces, audio, removeAudio)` — **çok parçalı düzenleme**
     * (2026-11-14, kullanıcı: ara kesimler + ses ekleme/çıkarma bölgeleri).
     *
     * - `pieces`: `[{startMs, endMs, mute}]` kaynak aralıkları, sırayla uç uca
     *   eklenir (aradan silinenler listede yok). `mute` parçada videonun kendi
     *   sesi atılır; sessizliği `experimentalSetForceAudioTrack` doldurur
     *   (sırada sesi olmayan öğeden sonra sesli öğe gelse de çıkış ses izi
     *   kesintisiz kalır).
     * - `audio`: `[{path, gapMs, lengthMs}]` ikinci (yalnız ses) sıra: her öğe
     *   önce `gapMs` boşluk, sonra ses dosyasının baştan `lengthMs`'i. Boşluk
     *   yalnız ses sırasında desteklenir (Media3 1.5 `addGap`). İki sıra
     *   karıştırılır (AudioMixer).
     * Efekt yok: döndürme bilgisi kaynaktaki gibi taşınır.
     */
    private fun edit(context: Context, a: Map<*, *>): Boolean {
        val path = a["path"] as? String ?: return false
        val target = a["target"] as? String ?: return false
        val pieces = (a["pieces"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: return false
        if (pieces.isEmpty()) return false
        val audio = (a["audio"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        val removeAudio = a["removeAudio"] == true
        // Döndürme (Ferrari H8.5): Dart saat yönünde verir; Media3
        // `setRotationDegrees` saat YÖNÜNÜN TERSİNE döndürür. Girdinin kendi
        // döndürme verisi çözücüde uygulanır → dönüş ekranda görünene göre.
        val rotation = ((a["rotation"] as? Number)?.toInt() ?: 0).mod(360)
        val videoEffects: List<androidx.media3.common.Effect> = if (rotation == 0) emptyList() else listOf(
            ScaleAndRotateTransformation.Builder()
                .setRotationDegrees((360 - rotation).toFloat())
                .build()
        )
        transformer?.cancel()
        val source = Uri.fromFile(File(path))
        var anyMute = false
        val videoItems = mutableListOf<EditedMediaItem>()
        for (p in pieces) {
            val s = (p["startMs"] as? Number)?.toLong() ?: return false
            val e = (p["endMs"] as? Number)?.toLong() ?: return false
            if (s < 0 || e <= s) return false
            val mute = p["mute"] == true
            if (mute) anyMute = true
            val media = MediaItem.Builder()
                .setUri(source)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(s)
                        .setEndPositionMs(e)
                        .build()
                )
                .build()
            videoItems.add(
                EditedMediaItem.Builder(media)
                    .setRemoveAudio(removeAudio || mute)
                    .setEffects(Effects(listOf(), videoEffects))
                    .build()
            )
        }
        val sequences = mutableListOf(EditedMediaItemSequence.Builder(videoItems).build())
        if (audio.isNotEmpty()) {
            val seq = EditedMediaItemSequence.Builder()
            var added = 0
            for (s in audio) {
                val apath = s["path"] as? String ?: return false
                val gapMs = (s["gapMs"] as? Number)?.toLong() ?: 0L
                val lenMs = (s["lengthMs"] as? Number)?.toLong() ?: return false
                if (lenMs <= 0) continue
                if (gapMs > 0) seq.addGap(gapMs * 1000L)
                val media = MediaItem.Builder()
                    .setUri(Uri.fromFile(File(apath)))
                    .setClippingConfiguration(
                        MediaItem.ClippingConfiguration.Builder()
                            .setStartPositionMs(0)
                            .setEndPositionMs(lenMs)
                            .build()
                    )
                    .build()
                seq.addItem(EditedMediaItem.Builder(media).setRemoveVideo(true).build())
                added++
            }
            // Yalnız boşluktan oluşan sıra Transformer'ı bekletir — ekleme yoksa sıra da yok.
            if (added > 0) sequences.add(seq.build())
        }
        val composition = Composition.Builder(sequences)
            .experimentalSetForceAudioTrack((anyMute && !removeAudio) || sequences.size > 1)
            .build()
        val t = Transformer.Builder(context)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(exportListener(target))
            .build()
        transformer = t
        return try {
            t.start(composition, target)
            pollProgress(t)
            true
        } catch (e: Exception) {
            transformer = null
            false
        }
    }

    /**
     * `frames(path, count, width, dir)` → eşit aralıklı [count] kare (JPEG,
     * [width] piksel genişlik) [dir] altına; yollar sırayla. Okunamayan kare
     * atlanır (liste kısa dönebilir). İzlekte koşar.
     */
    private fun frames(a: Map<*, *>): List<String> {
        val path = a["path"] as? String ?: return emptyList()
        val dir = a["dir"] as? String ?: return emptyList()
        val count = ((a["count"] as? Number)?.toInt() ?: 10).coerceIn(1, 24)
        val width = ((a["width"] as? Number)?.toInt() ?: 160).coerceIn(32, 480)
        val out = mutableListOf<String>()
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val ms = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            if (ms <= 0L) return out
            File(dir).mkdirs()
            for (i in 0 until count) {
                // Her dilimin ortası (ilk kare çoğu videoda siyah).
                val us = (ms * 1000L * (2 * i + 1)) / (2L * count)
                val bmp = try {
                    if (android.os.Build.VERSION.SDK_INT >= 27) {
                        r.getScaledFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, width, width * 2)
                    } else {
                        r.getFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    }
                } catch (e: Exception) { null } ?: continue
                try {
                    val scaled = if (bmp.width > width) {
                        android.graphics.Bitmap.createScaledBitmap(
                            bmp, width, (bmp.height.toLong() * width / bmp.width).toInt().coerceAtLeast(1), true)
                    } else bmp
                    val f = File(dir, "kare_$i.jpg")
                    f.outputStream().use { scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, it) }
                    if (scaled !== bmp) scaled.recycle()
                    out.add(f.path)
                } finally {
                    bmp.recycle()
                }
            }
        } catch (e: Exception) {
            // Okunamayan video: eldeki kareler döner (boş olabilir).
        } finally {
            try { r.release() } catch (e: Exception) {}
        }
        return out
    }

    /**
     * `frame(path, ms, target, rotation)` → [ms]'deki en yakın kare (anahtar
     * kare değil, tam kare) tam çözünürlükte JPEG; `rotation` saat yönünde
     * derece. `getFrameAtTime` videonun kendi döndürme verisini zaten uygular.
     * İzlekte koşar; başarısızsa yarım dosya silinir.
     */
    private fun frame(a: Map<*, *>): Boolean {
        val path = a["path"] as? String ?: return false
        val target = a["target"] as? String ?: return false
        val ms = (a["ms"] as? Number)?.toLong() ?: return false
        val rotation = ((a["rotation"] as? Number)?.toInt() ?: 0).mod(360)
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val bmp = r.getFrameAtTime(ms * 1000L, MediaMetadataRetriever.OPTION_CLOSEST) ?: return false
            val out = if (rotation == 0) bmp else {
                val m = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
                android.graphics.Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
            }
            try {
                File(target).outputStream().use {
                    out.compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, it)
                }
            } finally {
                if (out !== bmp) out.recycle()
                bmp.recycle()
            }
            true
        } catch (e: Exception) {
            File(target).delete()
            false
        } finally {
            try { r.release() } catch (e: Exception) {}
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
