// Oturum taslakları — bkz. `media_stubs.kt` başlığı.
package android.media.session

class MediaSession(context: android.content.Context, tag: String) {
    class Token

    open class Callback {
        open fun onPlay() {}
        open fun onPause() {}
        open fun onSkipToNext() {}
        open fun onSkipToPrevious() {}
        open fun onStop() {}
        open fun onSeekTo(pos: Long) {}
        open fun onFastForward() {}
        open fun onRewind() {}
    }

    var isActive: Boolean = false
    val sessionToken: Token? = Token()
    fun setCallback(callback: Callback?) {}
    fun setFlags(flags: Int) {}
    fun setMetadata(metadata: android.media.MediaMetadata?) {}
    fun setPlaybackState(state: PlaybackState?) {}
    fun release() {}

    companion object {
        const val FLAG_HANDLES_MEDIA_BUTTONS = 1
        const val FLAG_HANDLES_TRANSPORT_CONTROLS = 2
    }
}

class PlaybackState {
    class Builder {
        fun setActions(actions: Long): Builder = this
        fun setState(state: Int, position: Long, speed: Float): Builder = this
        fun build(): PlaybackState = PlaybackState()
    }

    companion object {
        const val ACTION_PLAY = 4L
        const val ACTION_PAUSE = 2L
        const val ACTION_PLAY_PAUSE = 512L
        const val ACTION_STOP = 1L
        const val ACTION_SEEK_TO = 256L
        const val ACTION_FAST_FORWARD = 64L
        const val ACTION_REWIND = 8L
        const val ACTION_SKIP_TO_NEXT = 32L
        const val ACTION_SKIP_TO_PREVIOUS = 16L
        const val STATE_PLAYING = 3
        const val STATE_PAUSED = 2
    }
}
