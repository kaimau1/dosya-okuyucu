// **Android API taslakları — YALNIZ yerel tür denetimi için.**
//
// Niye var (CI 331 kırmızı, 2026-09-02): `ci/*.kt` dosyaları bu depoda hiç
// derlenmiyordu; tek derleyici CI'daydı ve tek satırlık bir Kotlin tür hatası
// (`if (…) 0x80.toByte() else 0x00` → Int) bir derleme turunu (≈13 dk) yaktı.
//
// Bu dosya gerçek Android SDK'sının yerine geçmez ve APK'ya GİRMEZ; yalnız
// `tool/check_kotlin.sh` bunları kullanarak `ci/UsbMass.kt`i tür denetiminden
// geçirir. Yalnız o dosyanın kullandığı imzalar var; yeni bir Android API'si
// kullanılırsa buraya da eklenmeli (denetleyici "unresolved reference" der).
package android.hardware.usb

class UsbConstants {
    companion object {
        const val USB_CLASS_MASS_STORAGE = 8
        const val USB_ENDPOINT_XFER_BULK = 2
        const val USB_DIR_IN = 128
    }
}

class UsbEndpoint {
    val type: Int = 0
    val direction: Int = 0
    val address: Int = 0
}

class UsbInterface {
    val id: Int = 0
    val interfaceClass: Int = 0
    val interfaceSubclass: Int = 0
    val interfaceProtocol: Int = 0
    val endpointCount: Int = 0
    fun getEndpoint(index: Int): UsbEndpoint = UsbEndpoint()
}

class UsbDevice {
    val deviceName: String = ""
    val vendorId: Int = 0
    val productId: Int = 0
    val deviceClass: Int = 0
    val manufacturerName: String? = null
    val productName: String? = null
    val interfaceCount: Int = 0
    fun getInterface(index: Int): UsbInterface = UsbInterface()
}

class UsbDeviceConnection {
    fun claimInterface(itf: UsbInterface, force: Boolean): Boolean = true
    fun releaseInterface(itf: UsbInterface): Boolean = true
    fun close() {}
    fun bulkTransfer(
        endpoint: UsbEndpoint,
        buffer: ByteArray?,
        length: Int,
        timeout: Int
    ): Int = 0

    fun bulkTransfer(
        endpoint: UsbEndpoint,
        buffer: ByteArray?,
        offset: Int,
        length: Int,
        timeout: Int
    ): Int = 0

    fun controlTransfer(
        requestType: Int,
        request: Int,
        value: Int,
        index: Int,
        buffer: ByteArray?,
        length: Int,
        timeout: Int
    ): Int = 0
}

class UsbManager {
    companion object {
        const val ACTION_USB_DEVICE_ATTACHED =
            "android.hardware.usb.action.USB_DEVICE_ATTACHED"
        const val EXTRA_PERMISSION_GRANTED = "permission"
    }

    val deviceList: Map<String, UsbDevice> = emptyMap()
    fun hasPermission(device: UsbDevice): Boolean = true
    fun openDevice(device: UsbDevice): UsbDeviceConnection? = null
    fun requestPermission(device: UsbDevice, pi: android.app.PendingIntent) {}
}
