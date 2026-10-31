// `ci/kisisel/AsistanKopru.kt` (asistan köprüsü, yalnız kişisel derleme) için
// JVM denemesi (bkz. tool/check_kotlin.sh). Android çalışma zamanı gerektirmez.
package com.dosyaokuyucu.dosya_okuyucu

fun main() {
    fun check(name: String, ok: Boolean) {
        if (!ok) throw AssertionError("BAŞARISIZ: $name")
        println("ok  $name")
    }
    check("tek dosya", AsistanKopru.acilisCumlesi("fatura.pdf", 1) == "fatura.pdf açılıyor.")
    check("çok dosya", AsistanKopru.acilisCumlesi("fatura.pdf", 3) == "3 dosya bulundu, en yenisi açılıyor: fatura.pdf.")
    // AI kapsamı (Ajan ile aynı kural): gizli klasör ve engelli yol dönmez
    val k = AjanKapsam(listOf("/sd/DCIM/Camera"))
    check("kamera kapalı", !k.izinli("/sd/DCIM/Camera/a.jpg"))
    check("kamera kardeşi açık", k.izinli("/sd/DCIM/CameraX/a.jpg"))
    check("gizli klasör kapalı", !k.izinli("/sd/.dosya-okuyucu-cop/a.pdf"))
    check("belge açık", k.izinli("/sd/Download/kira.pdf"))
}
