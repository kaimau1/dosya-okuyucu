/// **Formül hata açıklaması** (Faz 36 madde 4: "#DEĞER! neden").
///
/// Hata kodu (Türkçe ya da İngilizce yazımı) → açıklama çeviri anahtarı.
/// Saf; formül çubuğundaki "?" düğmesi ve testler kullanır.
library;

String? formulaErrorKey(String value) => switch (value.trim().toUpperCase()) {
      '#DEĞER!' || '#VALUE!' => 'xp.err_value',
      '#SAYI/0!' || '#DIV/0!' => 'xp.err_div0',
      '#BAŞV!' || '#REF!' => 'xp.err_ref',
      '#AD?' || '#NAME?' => 'xp.err_name',
      '#YOK' || '#N/A' => 'xp.err_na',
      '#SAYI!' || '#NUM!' => 'xp.err_num',
      '#BOŞ!' || '#NULL!' => 'xp.err_null',
      '#YAYILMA!' || '#SPILL!' => 'xp.err_spill',
      '#HESAP!' || '#CALC!' => 'xp.err_calc',
      '#DÖNGÜ' => 'xp.err_cycle',
      _ => null,
    };
