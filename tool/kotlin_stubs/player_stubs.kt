// MediaPlayer + çizim/kaynak taslakları — bkz. `view_stubs.kt` başlığı.
package android.media

class PlaybackParams {
    fun setSpeed(speed: Float): PlaybackParams = this
}

class MediaPlayer {
    val duration: Int = 0
    val currentPosition: Int = 0
    val isPlaying: Boolean = false
    var playbackParams: PlaybackParams = PlaybackParams()

    fun setDataSource(path: String) {}
    fun setDisplay(holder: android.view.SurfaceHolder?) {}
    fun prepareAsync() {}
    fun start() {}
    fun pause() {}
    fun stop() {}
    fun release() {}
    fun seekTo(msec: Int) {}
    fun setVolume(left: Float, right: Float) {}

    fun setOnPreparedListener(listener: OnPreparedListener?) {}
    fun setOnCompletionListener(listener: OnCompletionListener?) {}
    fun setOnErrorListener(listener: OnErrorListener?) {}
    fun setOnVideoSizeChangedListener(listener: OnVideoSizeChangedListener?) {}

    fun interface OnPreparedListener {
        fun onPrepared(mp: MediaPlayer)
    }

    fun interface OnCompletionListener {
        fun onCompletion(mp: MediaPlayer)
    }

    fun interface OnErrorListener {
        fun onError(mp: MediaPlayer, what: Int, extra: Int): Boolean
    }

    fun interface OnVideoSizeChangedListener {
        fun onVideoSizeChanged(mp: MediaPlayer, width: Int, height: Int)
    }
}
