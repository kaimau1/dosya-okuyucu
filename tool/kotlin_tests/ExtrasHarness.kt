// `ci/Extras.kt`in saf karar işlevleri için JVM denemesi (bkz.
// tool/check_kotlin.sh). Android çalışma zamanı gerektirmez.
package com.dosyaokuyucu.dosya_okuyucu

fun main() {
    val day = Extras.DAY_MS
    val cal = java.util.Calendar.getInstance()
    cal.set(2026, 9, 18, 15, 30, 0)
    val now = cal.timeInMillis
    cal.set(2026, 9, 18, 0, 0, 0)
    val today = cal.timeInMillis
    fun check(name: String, ok: Boolean) {
        if (!ok) throw AssertionError("BAŞARISIZ: $name")
        println("ok  $name")
    }
    check("bugün son gün = 0", Extras.daysLeft(today + 9 * 60 * 60 * 1000, now) == 0)
    check("yarın = 1", Extras.daysLeft(today + day + 1000, now) == 1)
    check("dün = -1", Extras.daysLeft(today - 1000, now) == -1)
    check("3 gün içinde hatırlat", Extras.shouldRemind(3, 3))
    check("4 gün sonra hatırlatma yok", !Extras.shouldRemind(4, 3))
    check("8 gün geçmiş artık yok", !Extras.shouldRemind(-8, 3))
    check("temizlik: dolu + 7 gün geçti",
        Extras.shouldSuggestClean(true, 85, 0, now - 8 * day, now))
    check("temizlik: haftada bir",
        !Extras.shouldSuggestClean(true, 85, 0, now - 2 * day, now))
    check("temizlik: boş telefon, gereksiz yok",
        !Extras.shouldSuggestClean(true, 40, 0, 0, now))
    check("temizlik: bilinen gereksiz yeterli",
        Extras.shouldSuggestClean(true, 40, Extras.CLEAN_BYTES, 0, now))
    check("temizlik: kapalı", !Extras.shouldSuggestClean(false, 95, 0, 0, now))
    // G1.2 (B4): bağlantı/kısayol imzası.
    val key = ByteArray(32) { (it * 7 + 1).toByte() }
    val other = ByteArray(32) { (it * 5 + 3).toByte() }
    val sig = Extras.hmacHex(key, "file:/storage/emulated/0/a.pdf")
    check("imza 64 hex", sig.length == 64)
    check("imza doğru", Extras.sigOk(key, "file:/storage/emulated/0/a.pdf", sig))
    check("imza başka metinde geçmez", !Extras.sigOk(key, "file:/storage/emulated/0/b.pdf", sig))
    check("imza başka anahtarla geçmez", !Extras.sigOk(other, "file:/storage/emulated/0/a.pdf", sig))
    check("imza boş geçmez", !Extras.sigOk(key, "x", null) && !Extras.sigOk(key, "x", ""))
    check("imzalı file: kabul", Extras.linkAccepted("file:/storage/emulated/0/a.pdf", sig, key))
    check("imzasız file: red", !Extras.linkAccepted("file:/storage/emulated/0/a.pdf", null, key))
    check("sahte imzalı file: red", !Extras.linkAccepted("file:/data/data/x/y", sig, key))
    check("imzasız davet: red", !Extras.linkAccepted("davet:abc", null, key))
    check("imzasız app: kabul (statik kısayol)", Extras.linkAccepted("app:scan", null, key))
    check("boş bağlantı red", !Extras.linkAccepted("", null, key))
    check("imzalı yol kabul", Extras.pathAccepted("/storage/emulated/0/a.pdf", sig.let { Extras.hmacHex(key, "/storage/emulated/0/a.pdf") }, key))
    check("imzasız özel dizin yolu red", !Extras.pathAccepted("/data/data/com.x/files/a", null, key))
    check("imzasız ../ red", !Extras.pathAccepted("/storage/emulated/0/../../data/a", null, key))
    check("imzasız Android/data red", !Extras.pathAccepted("/storage/emulated/0/Android/data/x/a", null, key))
    check("imzasız eski kısayol (ortak depolama) kabul", Extras.pathAccepted("/storage/emulated/0/Download/a.pdf", null, key))
    val own = setOf("/storage/emulated/0/Download/a.pdf")
    check("imzasız kayıtlı kısayol kabul", Extras.pathAccepted("/storage/emulated/0/Download/a.pdf", null, key, own))
    check("imzasız kayıtsız yol red (API 26+)", !Extras.pathAccepted("/storage/emulated/0/Download/b.pdf", null, key, own))
    check("imzalı kayıtsız yol kabul", Extras.pathAccepted("/storage/emulated/0/Download/b.pdf", Extras.hmacHex(key, "/storage/emulated/0/Download/b.pdf"), key, own))
    println("Extras denemesi temiz.")
}
