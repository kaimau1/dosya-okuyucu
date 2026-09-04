// **Görünüm (View) taslakları — YALNIZ yerel tür denetimi için.**
//
// `ci/FloatingPlayer.kt` ekran üstünde bir pencere açıyor ve arayüzü ELLE
// (XML kaynak olmadan) kuruyor; kullandığı her sınıf burada. Gerekçe
// `media_stubs.kt` ile aynı: `ci/*.kt` yalnız CI'da derleniyor ve tek
// satırlık bir tür hatası 13 dakikalık bir APK turunu yakıyor.
//
// Bu dosya APK'ya GİRMEZ. Yeni bir API kullanılırsa buraya da eklenmeli
// (denetleyici "unresolved reference" der).
package android.view

import android.content.Context

object Gravity {
    const val TOP = 48
    const val START = 8388611
    const val CENTER = 17
    const val CENTER_VERTICAL = 16
}

class MotionEvent {
    val action: Int = 0
    val rawX: Float = 0f
    val rawY: Float = 0f
    val x: Float = 0f
    val y: Float = 0f

    companion object {
        const val ACTION_DOWN = 0
        const val ACTION_UP = 1
        const val ACTION_MOVE = 2
    }
}

open class View(context: Context) {
    var visibility: Int = VISIBLE
    val width: Int = 0
    val height: Int = 0
    var background: android.graphics.drawable.Drawable? = null
    var clipToOutline: Boolean = false
    var layoutParams: ViewGroup.LayoutParams? = null

    val resources: android.content.res.Resources = android.content.res.Resources()

    fun setPadding(left: Int, top: Int, right: Int, bottom: Int) {}
    fun setBackgroundColor(color: Int) {}
    fun setOnClickListener(listener: OnClickListener?) {}
    fun setOnTouchListener(listener: OnTouchListener?) {}

    fun interface OnClickListener {
        fun onClick(view: View)
    }

    fun interface OnTouchListener {
        fun onTouch(view: View, event: MotionEvent): Boolean
    }

    companion object {
        const val VISIBLE = 0
        const val GONE = 8
    }
}

open class ViewGroup(context: Context) : View(context) {
    open fun addView(child: View) {}
    open fun addView(child: View, params: LayoutParams) {}

    open class LayoutParams(width: Int, height: Int) {
        var width: Int = width
        var height: Int = height

        companion object {
            const val MATCH_PARENT = -1
            const val WRAP_CONTENT = -2
        }
    }
}

interface SurfaceHolder {
    interface Callback {
        fun surfaceCreated(holder: SurfaceHolder)
        fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int)
        fun surfaceDestroyed(holder: SurfaceHolder)
    }

    fun addCallback(callback: Callback)
}

class SurfaceView(context: Context) : View(context) {
    val holder: SurfaceHolder = object : SurfaceHolder {
        override fun addCallback(callback: SurfaceHolder.Callback) {}
    }
}

class WindowManager {
    fun addView(view: View, params: LayoutParams) {}
    fun updateViewLayout(view: View?, params: LayoutParams) {}
    fun removeView(view: View?) {}

    class LayoutParams(
        width: Int,
        height: Int,
        type: Int,
        flags: Int,
        format: Int
    ) : ViewGroup.LayoutParams(width, height) {
        var gravity: Int = 0
        var x: Int = 0
        var y: Int = 0

        companion object {
            const val TYPE_APPLICATION_OVERLAY = 2038
            const val TYPE_PHONE = 2002
            const val FLAG_NOT_FOCUSABLE = 8
        }
    }
}
