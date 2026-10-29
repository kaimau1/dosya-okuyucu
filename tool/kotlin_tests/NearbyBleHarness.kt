// `ci/NearbyBle.kt`in saf yardımcılarının JVM denemesi (tool/check_kotlin.sh).
package com.dosyaokuyucu.dosya_okuyucu

fun check(ok: Boolean, what: String) {
    if (!ok) throw AssertionError(what)
}

fun main() {
    val data = NearbyBle.encodeIdentity("a1b2c3d4", "Fatih'in telefonu çok uzun ad")
    check(data.size <= 24, "tarama yanıtı 24 baytı aşmamalı: ${data.size}")
    val (id, name) = NearbyBle.decodeIdentity(data)!!
    check(id == "a1b2c3d4", "kimlik gidip gelmeli: $id")
    check("Fatih'in telefonu".startsWith(name.take(17)), "ad başı korunmalı: $name")
    // Türkçe karakter ortadan bölünmez.
    val cut = NearbyBle.truncateUtf8("ğğğğğğğğğğğ", 5)
    check(cut.size == 4, "çok baytlı karakter bölünmemeli: ${cut.size}")
    check(String(cut, Charsets.UTF_8) == "ğğ", "kesilen metin geçerli UTF-8 olmalı")
    check(NearbyBle.decodeIdentity(byteArrayOf(1, 2)) == null, "kısa veri reddedilmeli")
    println("NearbyBle denemesi temiz.")
}
