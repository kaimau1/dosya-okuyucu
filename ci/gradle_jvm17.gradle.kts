
// --- CI: alt projelerde JVM hedefini 17'ye eşitle (eklenti uyumu) ---
// receive_sharing_intent gibi eklentiler Kotlin'i JVM 17'ye derliyor ama modül
// Java görevi 1.8 kalınca "jvm target compatibility" hatası veriyor.
// NOT: afterEvaluate KULLANMA (kök dosya sonunda "already evaluated" verir).
// plugins.withId lambda'sının alıcısı AppliedPlugin olduğundan Project'i
// `proj` ile açıkça yakalıyoruz; android eklentisi application/library eklentisi
// tam uygulandıktan sonra oluştuğu için com.android.base yerine bunları dinliyoruz.
subprojects {
    val proj = this
    // Kotlin derleme hedefi (lazy — değerlendirme zamanı gerektirmez).
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = "17"
    }
    // Android modülleri: Java kaynak/hedef uyumluluğunu 17 yap.
    plugins.withId("com.android.application") {
        (proj.extensions.findByName("android") as? com.android.build.gradle.BaseExtension)
            ?.apply {
                compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                compileOptions.targetCompatibility = JavaVersion.VERSION_17
            }
    }
    plugins.withId("com.android.library") {
        (proj.extensions.findByName("android") as? com.android.build.gradle.BaseExtension)
            ?.apply {
                compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                compileOptions.targetCompatibility = JavaVersion.VERSION_17
            }
    }
}
