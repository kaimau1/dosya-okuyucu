// **SdUnion motorunun JVM denemesi** — `tool/check_kotlin.sh` çalıştırır
// (ANDROID_ALL_JAR verildiyse). Motor yalnız java.io kullandığı için gerçek
// dosyalarla, cihaz olmadan sınanabiliyor: taşıma, çakışma, aynı içerik,
// yedek kipi, durdurma, kart dolu/yok, yazılmakta olan dosya.

import com.dosyaokuyucu.dosya_okuyucu.*
import java.io.File
import java.nio.file.Files
import java.util.concurrent.atomic.AtomicBoolean

var failures = 0
fun check(cond: Boolean, msg: String) { if (!cond) { failures++; println("FAIL: $msg") } else println("ok: $msg") }

const val DAY = 24L * 3600L * 1000L

fun cfg(primary: File, sd: File, move: Boolean = true, minAge: Int = 30, keepFree: Long = 0L) = SdUnionConfig(
    enabled = true, move = move, primary = primary.path, sdPath = sd.path,
    folders = listOf("DCIM", "Pictures"), minAgeDays = minAge, keepFreeBytes = keepFree,
    notify = false, doneTitle = "", doneBody = "", channelName = "")

fun write(f: File, content: String, ageDays: Long, now: Long) {
    f.parentFile.mkdirs(); f.writeText(content); f.setLastModified(now - ageDays * DAY)
}

fun main() {
    val now = System.currentTimeMillis()
    run {
        val base = Files.createTempDirectory("sdu").toFile()
        val primary = File(base, "emulated/0"); val sd = File(base, "1A2B-3C4D"); sd.mkdirs()
        write(File(primary, "DCIM/Camera/old.jpg"), "OLD-PHOTO", 40, now)
        write(File(primary, "DCIM/Camera/new.jpg"), "NEW", 1, now)
        write(File(primary, "DCIM/Camera/.pending-1-x.jpg"), "PEND", 40, now)
        write(File(primary, "DCIM/.thumbnails/t.jpg"), "THUMB", 40, now)
        write(File(primary, "Pictures/WhatsApp Images/w.jpg"), "CHAT", 40, now)
        write(File(primary, "Pictures/Screenshots/s.png"), "SHOT", 60, now)
        write(File(primary, "Download/d.pdf"), "NOT-IN-SCOPE", 90, now)
        val r = SdUnionEngine(cfg(primary, sd), AtomicBoolean(false), now).run()
        check(r.error == null, "taşıma hatasız (${r.error})")
        check(r.moved == 2, "iki dosya taşındı (${r.moved})")
        val moved = File(sd, "DCIM/Camera/old.jpg")
        check(moved.readText() == "OLD-PHOTO", "içerik aynı")
        check(Math.abs(moved.lastModified() - (now - 40 * DAY)) < 2000, "tarih korundu")
        check(!File(primary, "DCIM/Camera/old.jpg").exists(), "kaynak silindi")
        check(File(primary, "DCIM/Camera/new.jpg").exists() && !File(sd, "DCIM/Camera/new.jpg").exists(), "yeni dosya kaldı")
        check(File(primary, "DCIM/.thumbnails/t.jpg").exists(), "gizli klasöre dokunulmadı")
        check(File(primary, "DCIM/Camera/.pending-1-x.jpg").exists(), "gizli dosyaya dokunulmadı")
        check(File(primary, "Pictures/WhatsApp Images/w.jpg").exists(), "sohbet medyasına dokunulmadı")
        check(File(sd, "Pictures/Screenshots/s.png").exists(), "ekran görüntüsü taşındı")
        check(File(primary, "Download/d.pdf").exists(), "kapsam dışı klasör kaldı")
        val leftovers = sd.walkTopDown().filter { it.name.endsWith(SdUnionRules.TMP_SUFFIX) }.toList()
        check(leftovers.isEmpty(), "geçici dosya kalmadı")
        base.deleteRecursively()
    }
    run {
        val base = Files.createTempDirectory("sdu").toFile()
        val primary = File(base, "p"); val sd = File(base, "sd")
        write(File(primary, "DCIM/Camera/a.jpg"), "AAAA", 40, now)
        write(File(sd, "DCIM/Camera/a.jpg"), "BBBB-DIFFERENT", 40, now)
        write(File(primary, "DCIM/Camera/same.jpg"), "SAME", 40, now)
        write(File(sd, "DCIM/Camera/same.jpg"), "SAME", 40, now)
        val r = SdUnionEngine(cfg(primary, sd), AtomicBoolean(false), now).run()
        check(File(sd, "DCIM/Camera/a (1).jpg").readText() == "AAAA", "çakışmada yeni ad")
        check(File(sd, "DCIM/Camera/a.jpg").readText() == "BBBB-DIFFERENT", "kartın dosyası ezilmedi")
        check(!File(primary, "DCIM/Camera/same.jpg").exists() && !File(sd, "DCIM/Camera/same (1).jpg").exists(), "aynı içerik: kaynak silindi, kopya çoğalmadı")
        check(r.moved == 2, "iki iş sayıldı (${r.moved})")
        base.deleteRecursively()
    }
    run {
        val base = Files.createTempDirectory("sdu").toFile()
        val primary = File(base, "p"); val sd = File(base, "sd"); sd.mkdirs()
        write(File(primary, "DCIM/Camera/a.jpg"), "V1", 40, now)
        var r = SdUnionEngine(cfg(primary, sd, move = false), AtomicBoolean(false), now).run()
        check(r.moved == 1 && File(primary, "DCIM/Camera/a.jpg").exists() && File(sd, "DCIM/Camera/a.jpg").readText() == "V1", "yedek kipi kopyalar, kaynak kalır")
        r = SdUnionEngine(cfg(primary, sd, move = false), AtomicBoolean(false), now).run()
        check(r.moved == 0 && r.skipped == 1, "ikinci çalışma atlar")
        write(File(primary, "DCIM/Camera/a.jpg"), "V2-NEWER", 35, now)
        File(sd, "DCIM/Camera/a.jpg").setLastModified(now - 40 * DAY)
        r = SdUnionEngine(cfg(primary, sd, move = false), AtomicBoolean(false), now).run()
        check(File(sd, "DCIM/Camera/a.jpg").readText() == "V2-NEWER" && !File(sd, "DCIM/Camera/a (1).jpg").exists(), "değişen dosyanın yedeği tazelendi")
        base.deleteRecursively()
    }
    run {
        val base = Files.createTempDirectory("sdu").toFile()
        val primary = File(base, "p"); val sd = File(base, "sd"); sd.mkdirs()
        write(File(primary, "DCIM/Camera/a.jpg"), "A", 40, now)
        val r = SdUnionEngine(cfg(primary, sd), AtomicBoolean(true), now).run()
        check(r.error == "stopped" && r.moved == 0 && File(primary, "DCIM/Camera/a.jpg").exists(), "durdurulunca dokunulmaz")
        val full = SdUnionEngine(cfg(primary, sd, keepFree = Long.MAX_VALUE / 4), AtomicBoolean(false), now).run()
        check(full.error == "sd_full" && File(primary, "DCIM/Camera/a.jpg").exists(), "kart doluysa durur")
        val missing = SdUnionEngine(cfg(primary, File(base, "yok")), AtomicBoolean(false), now).run()
        check(missing.error == "sd_missing", "kart yoksa sd_missing")
        // 0 gün: yine de son 10 dakikada değişen dosyaya dokunulmaz.
        val fresh = File(primary, "DCIM/Camera/fresh.jpg"); fresh.writeText("F")
        val r0 = SdUnionEngine(cfg(primary, sd, minAge = 0), AtomicBoolean(false), now).run()
        check(fresh.exists() && !File(sd, "DCIM/Camera/fresh.jpg").exists(), "yazılmakta olan dosya beklenir")
        check(r0.moved == 1, "0 günde eski dosya taşındı (${r0.moved})")
        base.deleteRecursively()
    }
    run {
        // Büyük dosya + baş/son karşılaştırma
        val base = Files.createTempDirectory("sdu").toFile()
        val a = File(base, "a.bin"); val b = File(base, "b.bin")
        val data = ByteArray(300_000) { (it % 251).toByte() }
        a.writeBytes(data); b.writeBytes(data)
        check(SdUnionRules.sameContent(a, b), "aynı büyük dosya aynı")
        data[299_999] = 7; b.writeBytes(data)
        check(!SdUnionRules.sameContent(a, b), "sonu farklı dosya farklı")
        base.deleteRecursively()
    }
    println(if (failures == 0) "HEPSİ GEÇTİ" else "$failures HATA")
    if (failures != 0) System.exit(1)
}
