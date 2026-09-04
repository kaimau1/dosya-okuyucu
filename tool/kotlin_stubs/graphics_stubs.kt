// Bitmap taslakları — bkz. `media_stubs.kt` başlığı.
package android.graphics

class Bitmap

object BitmapFactory {
    class Options {
        var inJustDecodeBounds: Boolean = false
        var inSampleSize: Int = 1
        var outWidth: Int = 0
        var outHeight: Int = 0
    }

    fun decodeFile(path: String?, options: Options? = null): Bitmap? = null
}

object Color {
    const val BLACK = -16777216
    const val WHITE = -1

    fun argb(alpha: Int, red: Int, green: Int, blue: Int): Int = 0
}

object PixelFormat {
    const val TRANSLUCENT = -3
}
