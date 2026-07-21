
// --- CI: alt projelerde JVM hedefini 17'ye eşitle (eklenti uyumu) ---
// receive_sharing_intent gibi eklentiler Kotlin'i JVM 17'ye derliyor ama modül
// Java görevi 1.8 kalınca "jvm target compatibility" hatası veriyor.
//
// NOT: android { compileOptions } DSL'ini geç ayarlamak "sourceCompatibility has
// been finalized" hatası verir (AGP DSL'i kilitler). Bunun yerine derleme
// GÖREVLERİNİ doğrudan, lazy configureEach ile ayarlıyoruz — bu finalization'ı
// ve değerlendirme-zamanı sorunlarını (afterEvaluate) tamamen atlar.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = "17"
    }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}
