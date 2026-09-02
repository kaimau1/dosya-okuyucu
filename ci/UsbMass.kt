package com.dosyaokuyucu.dosya_okuyucu

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * **Ham USB yığın depolama sürücüsü (salt okunur).**
 *
 * Niye var (kullanıcı 2026-09-02): Android bazı cihazlarda takılan belleği
 * HİÇ bağlamıyor — ne dosya yolu veriyor, ne birim listesine koyuyor, ne de
 * klasör seçicide gösteriyor. O durumda geriye tek yol kalıyor: aygıtı
 * doğrudan sürmek. `UsbManager` ham USB erişimini uygulamaya AÇIK olarak
 * veriyor (kullanıcı izniyle), çünkü aygıt işletim sistemince
 * bağlanmadığında sahipsizdir.
 *
 * **Kapsam — bilerek dar:**
 * * yalnız **Bulk-Only Transport** (arayüz sınıf 8, protokol 0x50);
 *   UAS/CBI ayrı bir uygulama ister ve bellek çubuklarının neredeyse tamamı
 *   BBB konuşur;
 * * yalnız **okuma** (`READ(10)`). Yazma bilerek yok: yanlış yazılan bir FAT
 *   kullanıcının bütün belleğini kaybettirir, yanlış okuma ise en fazla
 *   dosyayı açmaz. Okuma cihazda doğrulanmadan yazma yazılmayacak.
 *
 * Dosya sistemi çözümlemesi (MBR/GPT, FAT12/16/32, exFAT) BURADA DEĞİL, saf
 * Dart tarafında (`lib/services/fm/usb/`): orası sentetik imajlarla test
 * edilebiliyor, Kotlin tarafı ise CI'da yalnız derleniyor. Bu sınır bilerek
 * çizildi — riskin tamamı test edilebilir tarafta.
 */
class UsbMass(private val context: Context) {

    private var connection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var inEndpoint: UsbEndpoint? = null
    private var outEndpoint: UsbEndpoint? = null
    private var tag = 1

    /** Sektör boyu (READ CAPACITY'den). */
    var blockSize = 0
        private set

    /** Toplam sektör sayısı. */
    var blockCount = 0L
        private set

    val isOpen: Boolean get() = connection != null

    /** İzin isteği sonucu bekleyen çağrı. */
    private var permissionCallback: ((Boolean) -> Unit)? = null
    private var receiver: BroadcastReceiver? = null

    /**
     * Aygıta erişim izni ister (kullanıcıya sistem penceresi çıkar).
     *
     * İzin ZORUNLU: izinsiz `openDevice` null döner. `FLAG_MUTABLE` Android
     * 12+ için şart — `UsbManager` yanıtı intent'e ekliyor, değiştirilemez
     * bir PendingIntent'te sonuç hiç gelmezdi.
     */
    fun requestPermission(device: UsbDevice, onResult: (Boolean) -> Unit) {
        val um = context.getSystemService(Context.USB_SERVICE) as UsbManager
        if (um.hasPermission(device)) {
            onResult(true)
            return
        }
        permissionCallback = onResult
        val rec = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                if (intent.action != ACTION_PERMISSION) return
                val granted = intent.getBooleanExtra(
                    UsbManager.EXTRA_PERMISSION_GRANTED, false
                )
                try { context.unregisterReceiver(this) } catch (e: Exception) {}
                receiver = null
                val cb = permissionCallback
                permissionCallback = null
                cb?.invoke(granted)
            }
        }
        receiver = rec
        val filter = IntentFilter(ACTION_PERMISSION)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(rec, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(rec, filter)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        val intent = PendingIntent.getBroadcast(
            context, 0, Intent(ACTION_PERMISSION).setPackage(context.packageName),
            flags
        )
        um.requestPermission(device, intent)
    }

    /**
     * Aygıtı açar: arayüzü sahiplenir, uçları bulur, kapasiteyi okur.
     *
     * Hata durumunda `false` döner ve her şeyi geri bırakır — yarım açık bir
     * aygıt bir sonraki denemeyi de engellerdi.
     */
    fun open(device: UsbDevice): Boolean {
        close()
        val um = context.getSystemService(Context.USB_SERVICE) as UsbManager
        var itf: UsbInterface? = null
        for (i in 0 until device.interfaceCount) {
            val cand = device.getInterface(i)
            if (cand.interfaceClass == UsbConstants.USB_CLASS_MASS_STORAGE &&
                cand.interfaceProtocol == 0x50
            ) {
                itf = cand
                break
            }
        }
        if (itf == null) return false
        var bulkIn: UsbEndpoint? = null
        var bulkOut: UsbEndpoint? = null
        for (i in 0 until itf.endpointCount) {
            val ep = itf.getEndpoint(i)
            if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
            if (ep.direction == UsbConstants.USB_DIR_IN) bulkIn = ep
            else bulkOut = ep
        }
        if (bulkIn == null || bulkOut == null) return false

        val conn = try { um.openDevice(device) } catch (e: Exception) { null }
            ?: return false
        if (!conn.claimInterface(itf, true)) {
            conn.close()
            return false
        }
        connection = conn
        usbInterface = itf
        inEndpoint = bulkIn
        outEndpoint = bulkOut

        // Bazı bellekler ilk komutu "birim değişti" diye reddeder; TEST UNIT
        // READY birkaç kez denenir (gerçek aygıtların bilinen davranışı).
        var ready = false
        for (i in 0 until 5) {
            if (testUnitReady()) { ready = true; break }
            Thread.sleep(100)
        }
        if (!ready) {
            close()
            return false
        }
        if (!readCapacity()) {
            close()
            return false
        }
        return true
    }

    fun close() {
        try {
            val itf = usbInterface
            val conn = connection
            if (itf != null && conn != null) conn.releaseInterface(itf)
            conn?.close()
        } catch (e: Exception) {
            // kapatırken hata: kaynak zaten gidiyor
        }
        connection = null
        usbInterface = null
        inEndpoint = null
        outEndpoint = null
        blockSize = 0
        blockCount = 0
    }

    /** `READ(10)` — [lba] sektöründen [count] sektör. */
    fun read(lba: Long, count: Int): ByteArray? {
        if (!isOpen || blockSize == 0) return null
        val length = count * blockSize
        val cdb = ByteArray(10)
        cdb[0] = 0x28 // READ(10)
        cdb[2] = ((lba shr 24) and 0xFF).toByte()
        cdb[3] = ((lba shr 16) and 0xFF).toByte()
        cdb[4] = ((lba shr 8) and 0xFF).toByte()
        cdb[5] = (lba and 0xFF).toByte()
        cdb[7] = ((count shr 8) and 0xFF).toByte()
        cdb[8] = (count and 0xFF).toByte()
        val out = ByteArray(length)
        return if (transfer(cdb, out, length, dataIn = true)) out else null
    }

    private fun testUnitReady(): Boolean =
        transfer(ByteArray(6), ByteArray(0), 0, dataIn = true)

    /** `READ CAPACITY(10)` — son sektörün numarası ve sektör boyu. */
    private fun readCapacity(): Boolean {
        val cdb = ByteArray(10)
        cdb[0] = 0x25
        val data = ByteArray(8)
        if (!transfer(cdb, data, 8, dataIn = true)) return false
        val bb = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
        val lastLba = bb.int.toLong() and 0xFFFFFFFFL
        val size = bb.int
        if (size <= 0 || size > 4096) return false
        blockSize = size
        blockCount = lastLba + 1
        return true
    }

    /**
     * **Bulk-Only Transport** akışı: CBW gönder → veri → CSW oku.
     *
     * CSW'nin durumu 0 değilse komut başarısızdır; veriyi yine de kabul etmek
     * kullanıcıya çöp bayt vermek olurdu.
     */
    private fun transfer(
        cdb: ByteArray,
        data: ByteArray,
        length: Int,
        dataIn: Boolean
    ): Boolean {
        val conn = connection ?: return false
        val epIn = inEndpoint ?: return false
        val epOut = outEndpoint ?: return false
        val thisTag = tag++

        val cbw = ByteBuffer.allocate(31).order(ByteOrder.LITTLE_ENDIAN)
        cbw.putInt(0x43425355) // 'USBC'
        cbw.putInt(thisTag)
        cbw.putInt(length)
        cbw.put(if (dataIn) 0x80.toByte() else 0x00)
        cbw.put(0) // LUN 0
        cbw.put(cdb.size.toByte())
        cbw.put(cdb)
        val cbwBytes = ByteArray(31)
        System.arraycopy(cbw.array(), 0, cbwBytes, 0, 31)
        if (conn.bulkTransfer(epOut, cbwBytes, cbwBytes.size, TIMEOUT) != 31) {
            return false
        }

        var moved = 0
        while (moved < length) {
            val n = conn.bulkTransfer(
                if (dataIn) epIn else epOut,
                data, moved, length - moved, TIMEOUT
            )
            if (n <= 0) return false
            moved += n
        }

        val csw = ByteArray(13)
        var read = 0
        while (read < 13) {
            val n = conn.bulkTransfer(epIn, csw, read, 13 - read, TIMEOUT)
            if (n <= 0) return false
            read += n
        }
        val cswBuf = ByteBuffer.wrap(csw).order(ByteOrder.LITTLE_ENDIAN)
        if (cswBuf.int != 0x53425355) return false // 'USBS'
        if (cswBuf.int != thisTag) return false
        cswBuf.int // kalan veri (residue) — okumada ilgilenmiyoruz
        return cswBuf.get().toInt() == 0
    }

    private companion object {
        const val ACTION_PERMISSION = "com.dosyaokuyucu.dosya_okuyucu.USB_PERMISSION"
        const val TIMEOUT = 5000
    }
}
