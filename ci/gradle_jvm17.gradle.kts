
// --- CI: alt projelerde JVM hedefini 17'ye eşitle (eklenti uyumu) ---
// receive_sharing_intent gibi eklentiler Kotlin'i JVM 17'ye derliyor ama modül
// Java görevi 1.8 kalınca "jvm target compatibility" hatası veriyor.
// NOT: afterEvaluate KULLANMA — bu blok kök build.gradle.kts sonuna eklendiği
// için bazı alt projeler o an zaten değerlendirilmiş olur ve afterEvaluate
// "already evaluated" hatası verir. Bunun yerine değerlendirme zamanından
// bağımsız plugins.withId + lazy configureEach kullanılır.
subprojects {
    // Kotlin derleme hedefi (lazy — değerlendirme zamanı gerektirmez).
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = "17"
    }
    // Android modülleri (app + library, ikisi de com.android.base uygular):
    // Java kaynak/hedef uyumluluğunu 17 yap.
    plugins.withId("com.android.base") {
        val ext = extensions.findByName("android")
        if (ext is com.android.build.gradle.BaseExtension) {
            ext.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            ext.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
    }
}
