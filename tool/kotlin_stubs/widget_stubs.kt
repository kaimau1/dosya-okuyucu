// Widget/çizim/oynatıcı taslakları — bkz. `view_stubs.kt` başlığı.
package android.widget

import android.content.Context
import android.view.View
import android.view.ViewGroup

open class TextView(context: Context) : View(context) {
    var text: CharSequence? = null
    var textSize: Float = 14f
    var maxLines: Int = 1

    fun setTextColor(color: Int) {}
}

open class FrameLayout(context: Context) : ViewGroup(context) {
    class LayoutParams(width: Int, height: Int, gravity: Int = 0) :
        ViewGroup.LayoutParams(width, height)
}

open class LinearLayout(context: Context) : ViewGroup(context) {
    var orientation: Int = HORIZONTAL
    var gravity: Int = 0

    class LayoutParams(width: Int, height: Int, weight: Float = 0f) :
        ViewGroup.LayoutParams(width, height)

    companion object {
        const val HORIZONTAL = 0
        const val VERTICAL = 1
    }
}

class SeekBar(context: Context) : View(context) {
    var max: Int = 0
    var progress: Int = 0

    fun setOnSeekBarChangeListener(listener: OnSeekBarChangeListener?) {}

    interface OnSeekBarChangeListener {
        fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean)
        fun onStartTrackingTouch(seekBar: SeekBar?)
        fun onStopTrackingTouch(seekBar: SeekBar?)
    }
}
