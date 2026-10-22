package com.dosyaokuyucu.dosya_okuyucu

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.SoftApConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * **QR ile dosya paylaşma** (2026-10-22) — `lib/services/fm/remote/qr_transfer.dart`
 * içindeki `QrNative`in Kotlin yüzü. Kanal `dosya/qr`, üç iş:
 *
 * 1. **scan** — Google kod tarayıcısı (Play Hizmetleri). Kamera izni İSTEMEZ,
 *    arayüzü ve modeli Play Hizmetleri'nden gelir (APK'ya ~0 MB).
 * 2. **startHotspot / stopHotspot** — `LocalOnlyHotspot`: ortak Wi-Fi yoksa
 *    gönderen telefon internetsiz geçici bir ağ kurar (Android 8+). Android
 *    13+ "Yakındaki cihazlar", öncesi konum izni + açık Konum ister; izin
 *    eksikse `perm` hatası (ayrıntıda hangisi) döner, isteği Dart yapar.
 * 3. **joinWifi / leaveWifi** — alıcı uygulama gönderenin geçici ağına
 *    `WifiNetworkSpecifier` ile bağlanır ve SÜRECİ o ağa bağlar: internetsiz
 *    ağda varsayılan yol mobil veride kalır, bağlamadan 192.168.x'e gidilemez.
 */
class QrTransfer(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "dosya/qr"
    }

    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var joinCallback: ConnectivityManager.NetworkCallback? = null

    private val cm get() =
        activity.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scan" -> scan(result)
            "startHotspot" -> startHotspot(result)
            "stopHotspot" -> {
                stopHotspot()
                result.success(null)
            }
            "joinWifi" -> joinWifi(
                call.argument<String>("ssid") ?: "",
                call.argument<String>("pass") ?: "",
                call.argument<String>("sec") ?: "",
                result,
            )
            "leaveWifi" -> {
                leaveWifi()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        stopHotspot()
        leaveWifi()
    }

    private fun scan(result: MethodChannel.Result) {
        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        try {
            GmsBarcodeScanning.getClient(activity, options).startScan()
                .addOnSuccessListener { result.success(it.rawValue) }
                .addOnCanceledListener { result.success(null) }
                .addOnFailureListener { result.error("unavailable", it.message, null) }
        } catch (e: Exception) {
            result.error("unavailable", e.message, null)
        }
    }

    private fun startHotspot(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unsupported", null, null)
            return
        }
        val needed = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.NEARBY_WIFI_DEVICES
        else Manifest.permission.ACCESS_FINE_LOCATION
        if (activity.checkSelfPermission(needed) != PackageManager.PERMISSION_GRANTED) {
            result.error("perm", null, if (Build.VERSION.SDK_INT >= 33) "nearby" else "location")
            return
        }
        if (Build.VERSION.SDK_INT < 33) {
            val lm = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val on = if (Build.VERSION.SDK_INT >= 28) lm.isLocationEnabled
            else lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            if (!on) {
                result.error("location_off", null, null)
                return
            }
        }
        stopHotspot()
        val wifi = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        var replied = false
        try {
            wifi.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                    reservation = res
                    if (replied) return
                    replied = true
                    result.success(describe(res))
                }

                override fun onStopped() {
                    reservation = null
                }

                override fun onFailed(reason: Int) {
                    if (replied) return
                    replied = true
                    result.error("failed", "reason $reason", null)
                }
            }, Handler(Looper.getMainLooper()))
        } catch (e: Exception) {
            if (!replied) {
                replied = true
                result.error("failed", e.message, null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun describe(res: WifiManager.LocalOnlyHotspotReservation): Map<String, String> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val c = res.softApConfiguration
            // WPA3-yalnız ağda alıcı WPA2 parolasıyla bağlanamaz (geçişli kip WPA2'yi de kabul eder).
            val sec = if (c.securityType == SoftApConfiguration.SECURITY_TYPE_WPA3_SAE) "sae" else "wpa"
            return mapOf("ssid" to (c.ssid ?: ""), "pass" to (c.passphrase ?: ""), "sec" to sec)
        }
        val c = res.wifiConfiguration
        return mapOf(
            "ssid" to (c?.SSID?.trim('"') ?: ""),
            "pass" to (c?.preSharedKey?.trim('"') ?: ""),
            "sec" to "wpa",
        )
    }

    private fun stopHotspot() {
        reservation?.close()
        reservation = null
    }

    private fun joinWifi(ssid: String, pass: String, sec: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || ssid.isEmpty()) {
            result.success(false)
            return
        }
        leaveWifi()
        val spec = WifiNetworkSpecifier.Builder().setSsid(ssid).apply {
            if (pass.isNotEmpty()) {
                if (sec == "sae") setWpa3Passphrase(pass) else setWpa2Passphrase(pass)
            }
        }.build()
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(spec)
            .build()
        var replied = false
        val main = Handler(Looper.getMainLooper())
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                cm.bindProcessToNetwork(network)
                main.post {
                    if (!replied) {
                        replied = true
                        result.success(true)
                    }
                }
            }

            override fun onUnavailable() {
                main.post {
                    if (!replied) {
                        replied = true
                        result.success(false)
                    }
                }
            }
        }
        joinCallback = callback
        try {
            cm.requestNetwork(request, callback, 60_000)
        } catch (e: Exception) {
            joinCallback = null
            result.success(false)
        }
    }

    private fun leaveWifi() {
        val cb = joinCallback ?: return
        joinCallback = null
        cm.bindProcessToNetwork(null)
        try {
            cm.unregisterNetworkCallback(cb)
        } catch (_: Exception) {}
    }
}
