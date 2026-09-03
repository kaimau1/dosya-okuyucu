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
