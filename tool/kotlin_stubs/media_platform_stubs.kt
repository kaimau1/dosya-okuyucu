// Medya oturumu ve grafik taslakları — bkz. `media_stubs.kt` başlığı.
package android.media

class MediaMetadata {
    class Builder {
        fun putString(key: String, value: String?): Builder = this
        fun putLong(key: String, value: Long): Builder = this
        fun putBitmap(key: String, value: android.graphics.Bitmap?): Builder = this
        fun build(): MediaMetadata = MediaMetadata()
    }

    companion object {
        const val METADATA_KEY_TITLE = "android.media.metadata.TITLE"
        const val METADATA_KEY_ARTIST = "android.media.metadata.ARTIST"
        const val METADATA_KEY_ALBUM = "android.media.metadata.ALBUM"
        const val METADATA_KEY_DISPLAY_TITLE = "android.media.metadata.DISPLAY_TITLE"
        const val METADATA_KEY_DISPLAY_SUBTITLE = "android.media.metadata.DISPLAY_SUBTITLE"
        const val METADATA_KEY_DURATION = "android.media.metadata.DURATION"
        const val METADATA_KEY_ALBUM_ART = "android.media.metadata.ALBUM_ART"
    }
}
