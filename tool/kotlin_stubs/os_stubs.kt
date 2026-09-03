// Android çerçevesinin geri kalanı — bkz. `android_stubs.kt` başlığı.
package android.os

object Build {
    object VERSION {
        const val SDK_INT = 34
    }

    object VERSION_CODES {
        const val LOLLIPOP = 21
        const val S = 31
        const val R = 30
        const val Q = 29
        const val O = 26
        const val N = 24
        const val M = 23
    }
}

interface IBinder
