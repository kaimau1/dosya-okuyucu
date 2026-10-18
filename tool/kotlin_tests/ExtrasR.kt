// `R` taslağı — yalnız `ci/Extras.kt`in gerçek Android jar'ına karşı yerel
// denetimi için (CI'da gerçek `R` sınıfını Gradle üretir; bkz. ci/res/).
package com.dosyaokuyucu.dosya_okuyucu

object R {
    object mipmap {
        const val ic_launcher = 40
    }

    object layout {
        const val widget_storage = 1
        const val widget_recent = 2
    }

    object id {
        const val w_root = 10
        const val w_title = 11
        const val w_free = 12
        const val w_total = 13
        const val w_bar = 14
        const val w_scan = 15
        const val w_scan_label = 16
        const val w_search = 17
        const val w_search_label = 18
        const val w_clean = 19
        const val w_clean_label = 20
        const val r_title = 30
        const val r_empty = 31
        const val r_1 = 32
        const val r_2 = 33
        const val r_3 = 34
        const val r_4 = 35
    }
}
