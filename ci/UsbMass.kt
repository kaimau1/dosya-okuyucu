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
 * HİÇ bağlamıyor — teşhis ekranı bunu ölçtü: birim `StorageManager`
 * listesinde "VendorCo USB sürücüsü · yol yok · unmounted" olarak duruyor,
 * `/proc/mounts` ve `/storage` bomboş. Bağlanmamış bellek klasör seçicide de
 * görünmez; geriye tek yol kalıyor: aygıtı doğrudan sürmek.
 *
 * **Kapsam — bilerek dar:**
 * * yalnız **Bulk-Only Transport** (arayüz sınıf 8, protokol 0x50);
 * * yalnız **okuma**. Yazma bilerek yok: yanlış yazılan bir FAT/NTFS tablosu
 *   kullanıcının bütün belleğini kaybettirir, yanlış okuma en fazla dosyayı
 *   açmaz.
 *
 * Dosya sistemi çözümlemesi BURADA DEĞİL, saf Dart tarafında
 * (`lib/services/fm/usb/`): orası sentetik imajlarla test edilebiliyor,
 * Kotlin tarafı CI'da yalnız derleniyor. Risk test edilebilir tarafta.
 *
 * **Her adım günlüğe yazılıyor** ([steps]): ilk denemede açılmadığında
 * "izin mi, sahiplenme mi, SCSI mi, biçim mi?" sorusunu ancak bu ayırt
 * ediyor — kullanıcı ekran görüntüsü gönderiyor, bizim elimizde tahminden
 * başka bir şey olmuyordu.
 */
class UsbMass(private val context: Context) {

    private var connection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var inEndpoint: UsbEndpoint? = null
    private var outEndpoint: UsbEndpoint? = null
    private var tag = 1
    private var lun = 0

    /** Açma sırasında ne olduğu — arayüz bunu gösteriyor. */
    val steps = ArrayList<String>()

    /** Başarısızlığın tek cümlelik sebebi (arayüzde gösterilir). */
    var error: String? = null
        private set

    var blockSize = 0
        private set

    var blockCount = 0L
        private set

    val isOpen: Boolean get() = connection != null

    private var permissionCallback: ((Boolean) -> Unit)? = null

    private fun log(line: String) {
        steps.add(line)
    }

    /**
     * Aygıta erişim izni ister (kullanıcıya sistem penceresi çıkar).
     *
     * `FLAG_MUTABLE` Android 12+ için şart: `UsbManager` yanıtı intent'e
     * ekliyor, değiştirilemez bir PendingIntent'te sonuç hiç gelmezdi.
     */
    fun requestPermission(device: UsbDevice, onResult: (Boolean) -> Unit) {
        val um = context.getSystemService(Context.USB_SERVICE) as UsbManager
        if (um.hasPermission(device)) {
            log("izin: zaten var")
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
                val cb = permissionCallback
                permissionCallback = null
                log(if (granted) "izin: verildi" else "izin: REDDEDİLDİ")
                cb?.invoke(granted)
            }
        }
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
            context, 0,
            Intent(ACTION_PERMISSION).setPackage(context.packageName),
            flags
        )
        um.requestPermission(device, intent)
    }

    /**
     * Aygıtı açar: arayüzü sahiplenir, uçları bulur, birimi hazırlar.
     *
     * Sıra gerçek aygıtların istediği sıradır — kısayol denemesi ilk turda
     * geri tepti: TEST UNIT READY tek başına yetmiyor, çünkü yeni takılmış
     * bir bellek ilk komuta **"Unit Attention"** (birim değişti) diye
     * CHECK CONDITION döner ve bunu ancak REQUEST SENSE temizler.
     */
    fun open(device: UsbDevice): Boolean {
        close()
        steps.clear()
        error = null
        val um = context.getSystemService(Context.USB_SERVICE) as UsbManager

        var itf: UsbInterface? = null
        for (i in 0 until device.interfaceCount) {
            val cand = device.getInterface(i)
            log(
                "arayüz $i: sınıf=${cand.interfaceClass} " +
                    "alt=${cand.interfaceSubclass} " +
                    "protokol=0x${Integer.toHexString(cand.interfaceProtocol)}"
            )
            if (cand.interfaceClass == UsbConstants.USB_CLASS_MASS_STORAGE &&
                cand.interfaceProtocol == 0x50
            ) {
                itf = cand
            }
        }
        if (itf == null) {
            error = "Yığın depolama (Bulk-Only) arayüzü yok"
            return false
        }

        var bulkIn: UsbEndpoint? = null
        var bulkOut: UsbEndpoint? = null
        for (i in 0 until itf.endpointCount) {
            val ep = itf.getEndpoint(i)
            if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
            if (ep.direction == UsbConstants.USB_DIR_IN) bulkIn = ep
            else bulkOut = ep
        }
        if (bulkIn == null || bulkOut == null) {
            error = "Toplu (bulk) uç bulunamadı"
            return false
        }
        log("uçlar: in=${bulkIn.address} out=${bulkOut.address}")

        val conn = try {
            um.openDevice(device)
        } catch (e: Exception) {
            log("openDevice: istisna ${e.message}")
            null
        }
        if (conn == null) {
            error = "Aygıt açılamadı (izin geri alınmış olabilir)"
            return false
        }
        if (!conn.claimInterface(itf, true)) {
            log("claimInterface: BAŞARISIZ")
            conn.close()
            error = "Arayüz sahiplenilemedi (aygıtı başka bir sürücü tutuyor)"
            return false
        }
        log("claimInterface: ok")

        connection = conn
        usbInterface = itf
        inEndpoint = bulkIn
        outEndpoint = bulkOut

        val maxLun = getMaxLun()
        log("maxLun: $maxLun")

        // Kart okuyucularda LUN 0 boş yuva olabilir; hazır olan ilk birim
        // seçiliyor (yoksa "bellek yok" deyip vazgeçerdik).
        for (candidate in 0..maxLun) {
            lun = candidate
            inquiry()
            if (!waitUnitReady()) {
                log("LUN $candidate: hazır değil")
                continue
            }
            if (!readCapacity()) {
                log("LUN $candidate: kapasite okunamadı")
                continue
            }
            log("LUN $candidate: $blockSize B x $blockCount sektör")
            return true
        }
        error = error ?: "Bellek hazır değil (birim yanıt vermiyor)"
        close()
        return false
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
        cdb[0] = 0x28
        cdb[2] = ((lba shr 24) and 0xFF).toByte()
        cdb[3] = ((lba shr 16) and 0xFF).toByte()
        cdb[4] = ((lba shr 8) and 0xFF).toByte()
        cdb[5] = (lba and 0xFF).toByte()
        cdb[7] = ((count shr 8) and 0xFF).toByte()
        cdb[8] = (count and 0xFF).toByte()
        val out = ByteArray(length)
        var status = transfer(cdb, out, length, dataIn = true)
        if (status == STATUS_FAILED) {
            // Bir kez daha: "Unit Attention" ilk komutta sık görülür.
            requestSense()
            status = transfer(cdb, out, length, dataIn = true)
        }
        return if (status == STATUS_OK) out else null
    }

    /**
     * `WRITE(10)` — [lba] sektöründen itibaren [data] yazar.
     *
     * **Yazma bilinçli olarak SON eklendi ve dar tutuldu:** yanlış yazılan
     * bir FAT tablosu kullanıcının bütün belleğini kaybettirir. Dosya
     * sistemi mantığı Dart tarafında ve sentetik imajlarla test edilmiş
     * durumda; burası yalnız "şu sektörlere şu baytları koy" köprüsü.
     */
    fun write(lba: Long, data: ByteArray): Boolean {
        if (!isOpen || blockSize == 0) return false
        if (data.isEmpty() || data.size % blockSize != 0) return false
        val count = data.size / blockSize
        val cdb = ByteArray(10)
        cdb[0] = 0x2A // WRITE(10)
        cdb[2] = ((lba shr 24) and 0xFF).toByte()
        cdb[3] = ((lba shr 16) and 0xFF).toByte()
        cdb[4] = ((lba shr 8) and 0xFF).toByte()
        cdb[5] = (lba and 0xFF).toByte()
        cdb[7] = ((count shr 8) and 0xFF).toByte()
        cdb[8] = (count and 0xFF).toByte()
        var status = transfer(cdb, data, data.size, dataIn = false)
        if (status == STATUS_FAILED) {
            val sense = requestSense()
            if (sense != null) {
                val key = sense[2].toInt() and 0x0F
                // 7 = yazma korumalı: yeniden denemenin anlamı yok.
                if (key == 7) {
                    error = "Bellek yazma korumalı"
                    return false
                }
            }
            status = transfer(cdb, data, data.size, dataIn = false)
        }
        return status == STATUS_OK
    }

    /** Aygıtta kaç mantıksal birim var? (Kart okuyucularda >0.) */
    private fun getMaxLun(): Int {
        val conn = connection ?: return 0
        val itf = usbInterface ?: return 0
        val buf = ByteArray(1)
        val n = try {
            conn.controlTransfer(0xA1, 0xFE, 0, itf.id, buf, 1, 2000)
        } catch (e: Exception) {
            -1
        }
        if (n != 1) return 0
        val value = buf[0].toInt() and 0xFF
        // Bozuk aygıtlar 0xFF döndürebiliyor; 15 üstü mantıksız.
        return if (value > 15) 0 else value
    }

    /** `INQUIRY` — aygıtın kendini tanıtması; bazı bellekler bunu bekliyor. */
    private fun inquiry() {
        val cdb = ByteArray(6)
        cdb[0] = 0x12
        cdb[4] = 36
        val data = ByteArray(36)
        val status = transfer(cdb, data, 36, dataIn = true)
        if (status == STATUS_OK) {
            val name = String(data, 8, 28, Charsets.US_ASCII).trim()
            log("inquiry: $name")
        } else {
            log("inquiry: durum $status")
        }
    }

    /**
     * Birim hazır olana kadar bekler.
     *
     * **İlk turun kök hatası buydu:** yeni takılan bir bellek ilk komuta
     * "Unit Attention" ile CHECK CONDITION döner; REQUEST SENSE ile
     * temizlenmezse aygıt aynı cevabı vermeye devam eder ve sürücü "hazır
     * değil" deyip vazgeçerdi. Dönen duyu (sense) verisi de günlüğe yazılıyor.
     */
    private fun waitUnitReady(): Boolean {
        for (attempt in 0 until 12) {
            val status = transfer(ByteArray(6), ByteArray(0), 0, dataIn = false)
            if (status == STATUS_OK) {
                log("hazır (deneme ${attempt + 1})")
                return true
            }
            if (status == STATUS_PHASE) {
                log("faz hatası → sıfırlama")
                resetRecovery()
                continue
            }
            val sense = requestSense() ?: run {
                log("duyu okunamadı")
                null
            }
            if (sense != null) {
                val key = sense[2].toInt() and 0x0F
                val asc = sense[12].toInt() and 0xFF
                val ascq = sense[13].toInt() and 0xFF
                log("duyu: key=$key asc=0x${Integer.toHexString(asc)} ascq=$ascq")
                // 3A = ortam yok (boş kart yuvası): beklemenin anlamı yok.
                if (key == 2 && asc == 0x3A) {
                    error = "Bu birimde ortam yok (boş yuva)"
                    return false
                }
                if (key == 0) return true
            }
            Thread.sleep(200)
        }
        return false
    }

    /** `REQUEST SENSE` — son hatanın sebebi; CHECK CONDITION'ı da temizler. */
    private fun requestSense(): ByteArray? {
        val cdb = ByteArray(6)
        cdb[0] = 0x03
        cdb[4] = 18
        val data = ByteArray(18)
        val status = transfer(cdb, data, 18, dataIn = true)
        return if (status == STATUS_OK) data else null
    }

    /**
     * **Sıfırlama kurtarması** (faz hatasından sonra zorunlu):
     * sınıfa özel "Bulk-Only Mass Storage Reset" + iki ucun takılmasını aç.
     */
    private fun resetRecovery() {
        val conn = connection ?: return
        val itf = usbInterface ?: return
        try {
            conn.controlTransfer(0x21, 0xFF, 0, itf.id, null, 0, TIMEOUT)
            inEndpoint?.let { clearHalt(it) }
            outEndpoint?.let { clearHalt(it) }
        } catch (e: Exception) {
            log("sıfırlama: istisna ${e.message}")
        }
    }

    /** Ucun HALT durumunu temizler (CLEAR_FEATURE / ENDPOINT_HALT). */
    private fun clearHalt(ep: UsbEndpoint) {
        val conn = connection ?: return
        try {
            conn.controlTransfer(0x02, 0x01, 0, ep.address, null, 0, TIMEOUT)
        } catch (e: Exception) {
            // temizlenemedi — sıradaki komut zaten hata verecek
        }
    }

    /** `READ CAPACITY(10)`; 2 TB üstünde (0xFFFFFFFF) 16 baytlığa düşer. */
    private fun readCapacity(): Boolean {
        val cdb = ByteArray(10)
        cdb[0] = 0x25
        val data = ByteArray(8)
        var status = transfer(cdb, data, 8, dataIn = true)
        if (status == STATUS_FAILED) {
            requestSense()
            status = transfer(cdb, data, 8, dataIn = true)
        }
        if (status != STATUS_OK) return false
        val bb = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
        val lastLba = bb.int.toLong() and 0xFFFFFFFFL
        val size = bb.int
        if (size <= 0 || size > 4096) return false
        if (lastLba == 0xFFFFFFFFL) return readCapacity16()
        blockSize = size
        blockCount = lastLba + 1
        return true
    }

    private fun readCapacity16(): Boolean {
        val cdb = ByteArray(16)
        // **0x7F üstü sabitler Byte'a SIĞMAZ** (Kotlin'de Byte işaretli):
        // `cdb[0] = 0x9E` derlenmez, açıkça çevrilmeli. Yerel denetleyici
        // (`tool/check_kotlin.sh`) bunu yakaladı; CI o satıra hiç gelmemişti.
        cdb[0] = 0x9E.toByte()
        cdb[1] = 0x10 // SERVICE ACTION IN / READ CAPACITY(16)
        cdb[13] = 32
        val data = ByteArray(32)
        if (transfer(cdb, data, 32, dataIn = true) != STATUS_OK) return false
        val bb = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
        val lastLba = bb.long
        val size = bb.int
        if (size <= 0 || size > 4096 || lastLba <= 0) return false
        blockSize = size
        blockCount = lastLba + 1
        return true
    }

    /**
     * **Bulk-Only Transport** akışı: CBW gönder → veri → CSW oku.
     *
     * Dönüş: [STATUS_OK] / [STATUS_FAILED] (CHECK CONDITION — REQUEST SENSE
     * gerekir) / [STATUS_PHASE] (sıfırlama gerekir) / [STATUS_TRANSPORT].
     */
    private fun transfer(
        cdb: ByteArray,
        data: ByteArray,
        length: Int,
        dataIn: Boolean
    ): Int {
        val conn = connection ?: return STATUS_TRANSPORT
        val epIn = inEndpoint ?: return STATUS_TRANSPORT
        val epOut = outEndpoint ?: return STATUS_TRANSPORT
        val thisTag = tag++

        val cbw = ByteBuffer.allocate(31).order(ByteOrder.LITTLE_ENDIAN)
        cbw.putInt(0x43425355) // 'USBC'
        cbw.putInt(thisTag)
        cbw.putInt(length)
        // Veri yokken yön biti anlamsızdır (standart: yok sayılır).
        //
        // **Kotlin tuzağı (CI 331 kırmızı):** `if (…) 0x80.toByte() else 0x00`
        // ifadesinin türü Byte DEĞİL Int olur (dallardan biri Int sabiti) ve
        // `put(Byte)` çağrısı derlenmez. Sabit atamalarda (`cdb[0] = 0x28`)
        // sorun çıkmaz, çünkü orada beklenen tür bellidir.
        cbw.put(if (length > 0 && dataIn) 0x80.toByte() else 0.toByte())
        cbw.put(lun.toByte())
        cbw.put(cdb.size.toByte())
        cbw.put(cdb)
        val cbwBytes = cbw.array()
        if (conn.bulkTransfer(epOut, cbwBytes, 31, TIMEOUT) != 31) {
            return STATUS_TRANSPORT
        }

        var moved = 0
        while (moved < length) {
            val n = conn.bulkTransfer(
                if (dataIn) epIn else epOut,
                data, moved, length - moved, TIMEOUT
            )
            if (n <= 0) {
                // Aygıt veriyi kesti: ucu aç ve CSW'yi yine de okumaya çalış,
                // yoksa sonraki komut da bozuk sırada gelirdi.
                clearHalt(if (dataIn) epIn else epOut)
                break
            }
            moved += n
        }

        val csw = ByteArray(13)
        var read = 0
        while (read < 13) {
            val n = conn.bulkTransfer(epIn, csw, read, 13 - read, TIMEOUT)
            if (n <= 0) {
                clearHalt(epIn)
                val retry = conn.bulkTransfer(epIn, csw, 0, 13, TIMEOUT)
                if (retry != 13) return STATUS_TRANSPORT
                read = 13
                break
            }
            read += n
        }
        val cswBuf = ByteBuffer.wrap(csw).order(ByteOrder.LITTLE_ENDIAN)
        if (cswBuf.int != 0x53425355) return STATUS_PHASE // 'USBS' değil
        if (cswBuf.int != thisTag) return STATUS_PHASE
        cswBuf.int // residue — okumada ilgilenmiyoruz
        return when (cswBuf.get().toInt()) {
            0 -> if (moved < length) STATUS_FAILED else STATUS_OK
            1 -> STATUS_FAILED
            else -> STATUS_PHASE
        }
    }

    private companion object {
        const val ACTION_PERMISSION = "com.dosyaokuyucu.dosya_okuyucu.USB_PERMISSION"
        const val TIMEOUT = 8000
        const val STATUS_OK = 0
        const val STATUS_FAILED = 1
        const val STATUS_PHASE = 2
        const val STATUS_TRANSPORT = -1
    }
}
