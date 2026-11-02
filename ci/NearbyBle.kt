package com.dosyaokuyucu.dosya_okuyucu

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.UUID

/**
 * **Yakındakiler — Bluetooth LE ile bulma ve davet** (2026-10-29).
 *
 * Kullanıcı isteği: *"Gönder/Al ayrımını kaldırın; yakındaki cihazlar ekrana
 * girer girmez birbirini otomatik görsün (BLE)."* Dart yüzü:
 * `lib/services/fm/remote/ble_nearby.dart`. Kanal `dosya/ble`.
 *
 * * **Görünme:** ekran açıkken telefon kendi hizmet UUID'sini yayınlar; tarama
 *   yanıtında üretici verisi = 4 bayt kurulum kimliği + kısaltılmış cihaz adı.
 * * **Bulma:** aynı UUID'yi süzen tarama; her cihaz en çok 2 sn'de bir
 *   Dart'a `found` olarak bildirilir.
 * * **Davet:** veri BLE'den AKMAZ (çok yavaş). Gönderen kendi geçici web
 *   sunucusunun adresini (gerekirse hotspot bilgisiyle — QR'daki metnin
 *   aynısı) karşının GATT sunucusundaki yazılabilir özelliğe yazar; alıcı
 *   bunu `invite` olarak alır ve dosyaları Wi-Fi'den çeker. Yani Bluetooth
 *   yalnız "el sıkışma", hız Wi-Fi'nin.
 *
 * İzin eksikse `perm` hatası döner; isteği Dart (permission_handler) yapar.
 */
@SuppressLint("MissingPermission")
class NearbyBle(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "dosya/ble"
        val SERVICE: UUID = UUID.fromString("7d3f1c2a-4b6e-4f0a-9c1d-5e8b2a6f0d41")
        val INVITE: UUID = UUID.fromString("7d3f1c2b-4b6e-4f0a-9c1d-5e8b2a6f0d41")
        const val MANUFACTURER = 0xFFFF
        const val NAME_BYTES = 20

        /** Kimlik (8 onaltılık) + ad → tarama yanıtı verisi. */
        fun encodeIdentity(id: String, name: String): ByteArray {
            val out = ByteArrayOutputStream()
            val clean = id.filter { it.isLetterOrDigit() }.padEnd(8, '0').take(8)
            for (i in 0 until 4) {
                out.write(clean.substring(i * 2, i * 2 + 2).toInt(16))
            }
            out.write(truncateUtf8(name, NAME_BYTES))
            return out.toByteArray()
        }

        fun decodeIdentity(data: ByteArray): Pair<String, String>? {
            if (data.size < 4) return null
            val id = (0 until 4).joinToString("") { "%02x".format(data[it].toInt() and 0xFF) }
            val name = String(data, 4, data.size - 4, Charsets.UTF_8)
            return id to name
        }

        /** UTF-8 karakterini ortadan bölmeden en çok [max] bayt. */
        fun truncateUtf8(text: String, max: Int): ByteArray {
            val bytes = text.toByteArray(Charsets.UTF_8)
            if (bytes.size <= max) return bytes
            var end = max
            // Devam baytı (10xxxxxx) üzerinde kesme: karakterin başına çekil.
            while (end > 0 && (bytes[end].toInt() and 0xC0) == 0x80) end--
            return bytes.copyOf(end)
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private val beacon = BleBeacon(activity.applicationContext) { address, bytes -> deliver(address, bytes) }
    private var scanning: ScanCallback? = null
    private val lastSeen = HashMap<String, Long>()

    private val manager get() =
        activity.applicationContext.getSystemService(Context.BLUETOOTH_SERVICE)
            as BluetoothManager?
    private val adapter: BluetoothAdapter? get() = manager?.adapter

    fun attach(ch: MethodChannel) {
        channel = ch
        ch.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "state" -> result.success(
                mapOf(
                    "supported" to (adapter != null &&
                        activity.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)),
                    "enabled" to (adapter?.isEnabled == true),
                )
            )
            "start" -> start(
                call.argument<String>("id") ?: "",
                call.argument<String>("name") ?: "",
                result,
            )
            "stop" -> {
                stop()
                result.success(null)
            }
            "bgState" -> result.success(
                mapOf(
                    "available" to (nearbyBackground != null),
                    "on" to (nearbyBackground?.isOn(activity) == true),
                )
            )
            "bgEnable" -> {
                val bg = nearbyBackground
                when {
                    bg == null -> result.error("unsupported", null, null)
                    missingPermissions().isNotEmpty() -> result.error("perm", null, missingPermissions())
                    else -> result.success(bg.enable(activity, call.arguments as? Map<String, Any?> ?: emptyMap()))
                }
            }
            "bgDisable" -> {
                nearbyBackground?.disable(activity)
                result.success(null)
            }
            "bgClearAsk" -> {
                nearbyBackground?.clearAsk(activity)
                result.success(null)
            }
            "invite" -> invite(
                call.argument<String>("address") ?: "",
                call.argument<String>("payload") ?: "",
                result,
            )
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        stop()
        channel = null
    }

    private fun missingPermissions(): List<String> {
        val needed = if (Build.VERSION.SDK_INT >= 31) listOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
        ) else listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        return needed.filter {
            activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
    }

    private fun start(id: String, name: String, result: MethodChannel.Result) {
        val a = adapter
        if (a == null ||
            !activity.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)
        ) {
            result.error("unsupported", null, null)
            return
        }
        val missing = missingPermissions()
        if (missing.isNotEmpty()) {
            result.error("perm", null, missing)
            return
        }
        if (!a.isEnabled) {
            result.error("off", null, null)
            return
        }
        halt()
        // Ekran aynı UUID'yi kendisi yayınlıyor: arka plan servisi (kişisel derleme) bu sürede susar.
        nearbyBackground?.pause()
        try {
            beacon.start(id, name, lowPower = false)
            scan(a)
            result.success(true)
        } catch (e: Exception) {
            halt()
            result.error("failed", e.message, null)
        }
    }

    private fun stop() {
        halt()
        nearbyBackground?.resume()
    }

    private fun halt() {
        beacon.stop()
        try {
            scanning?.let { adapter?.bluetoothLeScanner?.stopScan(it) }
        } catch (_: Exception) {}
        scanning = null
        lastSeen.clear()
    }

    // ── Bulma ───────────────────────────────────────────────────────────────

    private fun scan(a: BluetoothAdapter) {
        val scanner = a.bluetoothLeScanner ?: return
        val filters = listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build())
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                report(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach { report(it) }
            }
        }
        scanning = cb
        scanner.startScan(filters, settings, cb)
    }

    private fun report(result: ScanResult) {
        val data = result.scanRecord?.getManufacturerSpecificData(MANUFACTURER) ?: return
        val (id, name) = decodeIdentity(data) ?: return
        val address = result.device.address
        val now = System.currentTimeMillis()
        val last = lastSeen[address] ?: 0L
        if (now - last < 2000) return
        lastSeen[address] = now
        val payload = mapOf("id" to id, "name" to name, "address" to address, "rssi" to result.rssi)
        main.post { channel?.invokeMethod("found", payload) }
    }

    private fun deliver(address: String, bytes: ByteArray) {
        if (bytes.isEmpty() || bytes.size > 4096) return
        val text = String(bytes, Charsets.UTF_8)
        main.post {
            channel?.invokeMethod("invite", mapOf("payload" to text, "address" to address))
        }
    }

    // ── Davet gönderme (GATT istemcisi) ─────────────────────────────────────

    private fun invite(address: String, payload: String, result: MethodChannel.Result) {
        val a = adapter
        if (a == null || !a.isEnabled || address.isEmpty()) {
            result.success(false)
            return
        }
        if (missingPermissions().isNotEmpty()) {
            result.error("perm", null, missingPermissions())
            return
        }
        val bytes = payload.toByteArray(Charsets.UTF_8)
        var replied = false
        var discovering = false
        var gattRef: BluetoothGatt? = null

        fun finish(ok: Boolean) {
            main.post {
                if (replied) return@post
                replied = true
                result.success(ok)
                try {
                    gattRef?.disconnect()
                    gattRef?.close()
                } catch (_: Exception) {}
            }
        }

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    // Büyük MTU: davet tek yazmada gitsin. Bazı cihazlar
                    // onMtuChanged çağırmıyor — kısa süre sonra yine de keşfet.
                    if (!gatt.requestMtu(517)) {
                        discovering = true
                        gatt.discoverServices()
                    } else {
                        main.postDelayed({
                            if (!discovering && !replied) {
                                discovering = true
                                gatt.discoverServices()
                            }
                        }, 1500)
                    }
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    finish(false)
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                if (discovering) return
                discovering = true
                gatt.discoverServices()
            }

            @Suppress("DEPRECATION")
            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val ch = gatt.getService(SERVICE)?.getCharacteristic(INVITE)
                if (ch == null) {
                    finish(false)
                    return
                }
                val started = if (Build.VERSION.SDK_INT >= 33) {
                    gatt.writeCharacteristic(
                        ch, bytes, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    ) == BluetoothGatt.GATT_SUCCESS
                } else {
                    ch.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                    ch.value = bytes
                    gatt.writeCharacteristic(ch)
                }
                if (!started) finish(false)
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                finish(status == BluetoothGatt.GATT_SUCCESS)
            }
        }
        try {
            val device = a.getRemoteDevice(address)
            gattRef = if (Build.VERSION.SDK_INT >= 23) {
                device.connectGatt(activity, false, callback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(activity, false, callback)
            }
            main.postDelayed({ finish(false) }, 25_000)
        } catch (e: Exception) {
            finish(false)
        }
    }
}

/**
 * **Görünme (BLE reklamı) + davet alma (GATT sunucusu).** Yakındakiler ekranı ve kişisel derlemedeki
 * arka plan servisi (`ci/kisisel/NearbyBgService.kt`) ortak kullanır; davet baytları [onInvite]'a
 * (gönderen adresi, ham veri) gider.
 */
@SuppressLint("MissingPermission")
class BleBeacon(
    private val context: Context,
    private val onInvite: (String, ByteArray) -> Unit,
) {
    private var server: BluetoothGattServer? = null
    private var advertising: AdvertiseCallback? = null
    private val prepared = HashMap<String, ByteArrayOutputStream>()

    private val manager get() =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?

    /**
     * [lowPower]: arka planda ~1 sn aralıklı yayın (pil dostu); ekran açıkken düşük gecikme
     * (karşı taraf hemen bulsun).
     */
    fun start(id: String, name: String, lowPower: Boolean) {
        stop()
        val a = manager?.adapter ?: return
        if (!a.isEnabled) return
        openServer()
        advertise(a, id, name, lowPower)
    }

    fun stop() {
        try {
            advertising?.let { manager?.adapter?.bluetoothLeAdvertiser?.stopAdvertising(it) }
        } catch (_: Exception) {}
        advertising = null
        try {
            server?.close()
        } catch (_: Exception) {}
        server = null
        synchronized(prepared) { prepared.clear() }
    }

    private fun advertise(a: BluetoothAdapter, id: String, name: String, lowPower: Boolean) {
        val advertiser = a.bluetoothLeAdvertiser ?: return // çevre birimi kipi yok
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(
                if (lowPower) AdvertiseSettings.ADVERTISE_MODE_LOW_POWER
                else AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
            )
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .setTimeout(0)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(NearbyBle.SERVICE))
            .build()
        val response = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addManufacturerData(NearbyBle.MANUFACTURER, NearbyBle.encodeIdentity(id, name))
            .build()
        val cb = object : AdvertiseCallback() {
            override fun onStartFailure(errorCode: Int) {
                advertising = null
            }
        }
        advertising = cb
        advertiser.startAdvertising(settings, data, response, cb)
    }

    private fun openServer() {
        val m = manager ?: return
        val callback = object : BluetoothGattServerCallback() {
            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?,
            ) {
                val bytes = value ?: ByteArray(0)
                if (characteristic.uuid == NearbyBle.INVITE) {
                    if (preparedWrite) {
                        synchronized(prepared) {
                            prepared.getOrPut(device.address) { ByteArrayOutputStream() }.write(bytes)
                        }
                    } else {
                        onInvite(device.address, bytes)
                    }
                }
                if (responseNeeded) {
                    server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, bytes)
                }
            }

            override fun onExecuteWrite(device: BluetoothDevice, requestId: Int, execute: Boolean) {
                val buffer = synchronized(prepared) { prepared.remove(device.address) }
                if (execute && buffer != null) onInvite(device.address, buffer.toByteArray())
                server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }
        }
        val s = m.openGattServer(context, callback) ?: return
        val service = BluetoothGattService(NearbyBle.SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(
            BluetoothGattCharacteristic(
                NearbyBle.INVITE,
                BluetoothGattCharacteristic.PROPERTY_WRITE,
                BluetoothGattCharacteristic.PERMISSION_WRITE,
            )
        )
        s.addService(service)
        server = s
    }
}

/**
 * Kişisel derlemedeki **arka planda görünürlük** (`ci/kisisel/NearbyBgService.kt`). Genel derlemede
 * sınıf yok → [nearbyBackground] null, Yakındakiler'de anahtar görünmez.
 */
interface NearbyBackground {
    fun isOn(ctx: Context): Boolean
    fun enable(ctx: Context, args: Map<String, Any?>): Boolean
    fun disable(ctx: Context)
    fun clearAsk(ctx: Context)
    fun pause()
    fun resume()
}

/** Yansımayla: genel derleme kişisel sınıfa derleme zamanında bağlanmasın (proguard-rules.pro'da korunur). */
val nearbyBackground: NearbyBackground? by lazy {
    try {
        Class.forName("com.dosyaokuyucu.dosya_okuyucu.NearbyBgService\$Control")
            .getField("INSTANCE").get(null) as NearbyBackground
    } catch (_: Throwable) {
        null
    }
}
