package com.dosyaokuyucu.dosya_okuyucu

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * **Aktar şifrelemesinin hızlı yolu** (Faz G5, 2026-11-13) — Dart tarafı
 * `lib/services/fm/remote/peer_crypto.dart` `NativeAead`, kanal `dosya/aead`.
 *
 * Niye Kotlin: saf Dart AES-GCM (pointycastle) SFTP'yi 14 → 1 MB/sn düşürmüştü
 * (HAFIZA). `javax.crypto` Android'de Conscrypt/BoringSSL'e gider; ARMv8 AES +
 * PMULL komutlarıyla GB/sn düzeyinde. Kayıt başına (≤ 1 MiB) tek çağrı.
 *
 * Kanal **arka plan iş kuyruğunda**: şifreleme ana (arayüz) iş parçacığını
 * tutmaz. İki iş: `seal` (şifre + 16 bayt etiket sonda) ve `open` (etiket
 * tutmazsa `etiket` hatası).
 */
object AktarAead {
    const val CHANNEL = "dosya/aead"

    fun attach(messenger: BinaryMessenger) {
        val queue = messenger.makeBackgroundTaskQueue()
        MethodChannel(messenger, CHANNEL, StandardMethodCodec.INSTANCE, queue)
            .setMethodCallHandler { call, result ->
                val mode = when (call.method) {
                    "seal" -> Cipher.ENCRYPT_MODE
                    "open" -> Cipher.DECRYPT_MODE
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                try {
                    val key = call.argument<ByteArray>("k")!!
                    val nonce = call.argument<ByteArray>("n")!!
                    val data = call.argument<ByteArray>("d")!!
                    val aad = call.argument<ByteArray>("a") ?: ByteArray(0)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(mode, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
                    if (aad.isNotEmpty()) cipher.updateAAD(aad)
                    result.success(cipher.doFinal(data))
                } catch (e: AEADBadTagException) {
                    result.error("etiket", null, null)
                } catch (e: Exception) {
                    result.error("yerel", e.javaClass.simpleName, null)
                }
            }
    }
}
