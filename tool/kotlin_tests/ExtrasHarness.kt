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
    println("Extras denemesi temiz.")
}
