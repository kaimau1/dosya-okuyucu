# CI'da android/app/proguard-rules.pro olarak kopyalanır (build-apk.yml).
# Flutter'ın Gradle eklentisi release küçültmede (R8) bu dosyayı otomatik dahil eder.
#
# ML Kit metin tanıma: APK'ya yalnızca LATIN modeli gömülü
# (google_mlkit_text_recognition). Eklentinin Java köprüsü Çince/Devanagari/
# Japonca/Korece tanıyıcı sınıflarına da referans veriyor; o AAR'lar ekli
# olmadığından R8 "Missing class" ile derlemeyi KESER. Bu diller bilinçli
# olarak pakette yok (APK boyutu); referanslar hiç çalışmayan koldadır →
# uyarıyı sustur (bkz. HAFIZA 2026-07-22).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Flutter 3.44 / AGP 9'un R8'i WorkManager'ın Room veritabanını kırıyordu:
# Room `<Sınıf>_Impl`i adla (yansımayla) arıyor; sınıf adı küçültülünce açılışta
# "Failed to create an instance of class androidx.work.impl.WorkDatabase" ile
# ÇÖKÜYOR (2026-10-22 telefonda ölçüldü; 3.29'un R8'i dokunmuyordu).
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# AGP 9 R8'i varsayılan TAM kipte: Gson'un TypeToken jenerik imzası siliniyor →
# flutter_local_notifications "Missing type parameter" atıyor, Dart açılışı
# takılıp ekran SİYAH kalıyordu (2026-10-22 telefonda). Eklentinin önerdiği kurallar.
-keepattributes Signature
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# shared_preferences_android 2.5+: SharedPreferencesAsync yolu Kotlin sınıfını
# Dart'tan JNI ile ADIYLA çağırıyor; R8 açıkken `getAll` silinip/yeniden
# adlandırılınca "NoSuchMethodError … SharedPreferencesApiRegistrar.getAll"
# (kullanıcı hata kaydı 2026-10-22, R8'li yerel derleme). R8 şu an kapalı
# (prepare_android.sh 6c) — yeniden açılınca gerekli.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
