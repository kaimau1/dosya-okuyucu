// Çizim (Drawable) taslakları — bkz. `view_stubs.kt` başlığı.
package android.graphics.drawable

open class Drawable

class GradientDrawable : Drawable() {
    var cornerRadius: Float = 0f

    fun setColor(color: Int) {}
}
