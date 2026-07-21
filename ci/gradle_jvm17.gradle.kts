
// --- CI: alt projelerde JVM hedefini 17'ye eşitle (eklenti uyumu) ---
// receive_sharing_intent gibi eklentiler Kotlin'i JVM 17'ye derliyor ama modül
// Java görevi 1.8 kalınca "jvm target compatibility" hatası veriyor. Tüm alt
// projelerde Java compileOptions + Kotlin jvmTarget hedefini 17'ye eşitle.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            (ext as com.android.build.gradle.BaseExtension).compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions.jvmTarget = "17"
        }
    }
}
