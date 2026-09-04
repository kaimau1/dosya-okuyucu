package com.dosyaokuyucu.dosya_okuyucu

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView

/**
 * **Ekran üstünde yüzen video oynatıcı** (kullanıcı isteği 2026-09-03:
 * *"ekran üstünde ekran video oynatıcı sistemi yapalım, her türlü özelliği
 * olsun"*).
 *
 * Video başka uygulamaların ÜSTÜNDE, küçük bir pencerede oynar: kullanıcı
 * WhatsApp'a bakarken ders videosu akmaya devam eder. YouTube'un, Telegram'ın
 * ve sistem oynatıcılarının yaptığı iş.
 *
 * ## Niye native, niye Flutter değil
 * Flutter tek bir `FlutterView` çizer ve o görünüm uygulamanın penceresine
 * bağlıdır: uygulama arkaya alındığında çizim durur. Başka uygulamaların
 * üstünde bir pencere ancak `WindowManager` + `TYPE_APPLICATION_OVERLAY` ile
 * açılır ve içine Flutter koymak (`FlutterEngineGroup` + ikinci sunum)
 * derleme zincirini oynatmak demekti (HAFIZA'daki yasak). Burada çerçevenin
 * kendi `MediaPlayer`ı bir `SurfaceView`e çiziyor — ek paket yok.
 *
 * ## Niye Android'in kendi PiP'i değil
 * `enterPictureInPictureMode` yalnız uygulamanın kendi Activity'sini küçültür:
 * kullanıcı BAŞKA bir uygulamaya geçtiğinde (ana ekrana çıkmadan) pencere
 * kapanır, boyutu sistemin dediği kadardır ve kendi düğmelerimizi
 * koyamayız. Kullanıcı "her türlü özelliği olsun" dedi.
 *
 * ## Özellikler
 * Sürükleyerek taşıma, köşeden boyutlandırma, çift dokunuşla üç hazır boy,
 * oynat/duraklat, ±10 sn, sürüklenebilir konum çubuğu, hız (1x/1.5x/2x),
 * sessize alma, uygulamaya dönme (kaldığı yerden) ve kapatma.
 *
 * ## Yaşam döngüsü
 * Servis ön planda (`mediaPlayback`): arka planda ses kesilmesin. Görev
 * listesinden uygulama kapatılırsa servis de gider (`stopWithTask`), yani
 * ekranda sahipsiz bir pencere kalmaz. Kapanırken ve uygulamaya dönerken
 * KONUM Dart'a bildirilir — video kaldığı yerden devam eder.
 *
 * Flutter'a hiç bağlı değil: `tool/check_kotlin.sh` bunu taslaklarla tür
 * denetiminden geçirebiliyor.
 */
object FloatingBridge {

    /** Servis olayları Dart'a: `("closed"|"expand", konum ms)`. */
    var onEvent: ((String, Long) -> Unit)? = null

    /** Dart dinlemiyorken (uygulama kapalı) gelen son olay. */
    private var pending: Pair<String, Long>? = null

    /** Pencere şu an ekranda mı? */
    var running = false
        internal set

    const val ACTION_OPEN = "com.dosyaokuyucu.dosya_okuyucu.float.open"
    const val ACTION_CLOSE = "com.dosyaokuyucu.dosya_okuyucu.float.close"
    const val EXTRA_PATH = "path"
    const val EXTRA_POSITION = "position"
    const val EXTRA_TITLE = "title"

    /**
     * Bildirimin alt satırı ve kanal adı — **Dart'tan geliyor**.
     *
     * Uygulama üç dilde (tr/en/ar); native tarafa gömülü Türkçe bir cümle
     * İngilizce kullanan birinin bildirim gölgesinde Türkçe çıkardı. Metni
     * bilen taraf Dart, o yüzden metni o gönderiyor.
     */
    const val EXTRA_SUBTITLE = "subtitle"
    const val CHANNEL_ID = "floating_player"
    const val NOTIFICATION_ID = 91002

    fun emit(event: String, positionMs: Long) {
        val callback = onEvent
        if (callback == null) {
            // Uygulama kapalıyken kapatılan pencerenin konumu kaybolmasın:
            // Dart açılınca `floatingPending` ile soruyor.
            pending = Pair(event, positionMs)
            return
        }
        callback(event, positionMs)
    }

    /** Bekleyen olayı verir ve TEMİZLER (iki kez işlenmesin). */
    fun takePending(): Map<String, Any>? {
        val p = pending ?: return null
        pending = null
        return mapOf("event" to p.first, "position" to p.second)
    }
}

class FloatingPlayerService : Service() {

    private var windowManager: WindowManager? = null
    private var root: FrameLayout? = null
    private var surface: SurfaceView? = null
    private var player: MediaPlayer? = null
    private var seekBar: SeekBar? = null
    private var playButton: TextView? = null
    private var speedButton: TextView? = null
    private var muteButton: TextView? = null
    private var controls: View? = null
    private val handler = Handler(Looper.getMainLooper())

    private var path: String? = null
    private var title: String = ""
    private var subtitle: String = ""
    private var pendingSeek: Long = 0
    private var videoWidth = 16
    private var videoHeight = 9
    private var muted = false
    private var speedIndex = 0
    private var prepared = false
    private var sizeStep = 1

    /** Kullanıcı çubuğu sürüklerken konum güncellemesi durur. */
    private var dragging = false

    private val speeds = floatArrayOf(1f, 1.25f, 1.5f, 2f)

    private val ticker = object : Runnable {
        override fun run() {
            val p = player
            if (p != null && prepared && !dragging) {
                try {
                    seekBar?.progress = p.currentPosition
                } catch (e: Exception) {
                    // Oynatıcı kapanıyor olabilir.
                }
            }
            handler.postDelayed(this, 500)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == FloatingBridge.ACTION_CLOSE) {
            stopSelf()
            return START_NOT_STICKY
        }
        val newPath = intent?.getStringExtra(FloatingBridge.EXTRA_PATH)
        if (newPath.isNullOrEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        path = newPath
        title = intent.getStringExtra(FloatingBridge.EXTRA_TITLE) ?: ""
        subtitle = intent.getStringExtra(FloatingBridge.EXTRA_SUBTITLE) ?: ""
        pendingSeek = intent.getLongExtra(FloatingBridge.EXTRA_POSITION, 0L)
        startForegroundSafely()
        if (root == null) buildWindow()
        openMedia()
        FloatingBridge.running = true
        return START_NOT_STICKY
    }

    /**
     * Ön plan bildirimi: arka planda ses kesilmesin.
     *
     * Bildirim İÇERİĞİ bilerek yalın (başlık + "yüzen oynatıcı"): asıl
     * denetim ekrandaki pencerede. Kanal yoksa kurulur; `MediaService`in
     * kanalıyla karışmasın diye ayrı kimlik.
     */
    private fun startForegroundSafely() {
        try {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    FloatingBridge.CHANNEL_ID,
                    if (subtitle.isEmpty()) "Floating player" else subtitle,
                    NotificationManager.IMPORTANCE_LOW
                )
                manager.createNotificationChannel(channel)
            }
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, FloatingBridge.CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
            builder.setContentTitle(if (title.isEmpty()) "Video" else title)
            builder.setContentText(subtitle)
            builder.setSmallIcon(android.R.drawable.ic_media_play)
            builder.setOngoing(true)
            val notification = builder.build()
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(
                    FloatingBridge.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(FloatingBridge.NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Bildirim kurulamadı: pencere yine açılır, yalnız arka planda
            // sistem servisi öldürebilir.
        }
    }

    // ── Pencere ───────────────────────────────────────────────────────────

    private fun buildWindow() {
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm
        val density = resources.displayMetrics.density
        val frame = FrameLayout(this)
        val background = GradientDrawable()
        background.setColor(Color.BLACK)
        background.cornerRadius = 12f * density
        frame.background = background
        frame.clipToOutline = true

        val video = SurfaceView(this)
        frame.addView(
            video,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )
        video.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                try {
                    player?.setDisplay(holder)
                } catch (e: Exception) {
                }
            }

            override fun surfaceChanged(
                holder: SurfaceHolder,
                format: Int,
                width: Int,
                height: Int
            ) {
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
            }
        })
        surface = video

        frame.addView(buildControls(density))
        root = frame

        val params = WindowManager.LayoutParams(
            (220 * density).toInt(),
            (124 * density).toInt(),
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = (16 * density).toInt()
        params.y = (96 * density).toInt()
        try {
            wm.addView(frame, params)
        } catch (e: Exception) {
            // İzin geri alınmış olabilir: pencere açılamaz.
            stopSelf()
            return
        }
        attachDrag(frame, params, density)
        handler.post(ticker)
    }

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    /**
     * Denetimler: üstte başlık + dön/kapat, altta oynatma düğmeleri ve
     * konum çubuğu.
     *
     * Simgeler **Unicode karakter**: kendi çizim kaynaklarımız yok (CI
     * `res/` klasörünü her derlemede yeniden üretiyor) ve sistem
     * çizimlerinin adları sürümden sürüme değişiyor. Karakterler her ROM'da
     * aynı görünüyor.
     */
    private fun buildControls(density: Float): View {
        val column = LinearLayout(this)
        column.orientation = LinearLayout.VERTICAL
        column.setBackgroundColor(Color.argb(120, 0, 0, 0))

        val top = LinearLayout(this)
        top.orientation = LinearLayout.HORIZONTAL
        top.gravity = Gravity.CENTER_VERTICAL
        val label = TextView(this)
        label.text = title
        label.setTextColor(Color.WHITE)
        label.textSize = 11f
        label.maxLines = 1
        label.setPadding((8 * density).toInt(), 0, 0, 0)
        top.addView(
            label,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        )
        top.addView(button("⤢", density) { expandToApp() })
        top.addView(button("✕", density) { closeWindow() })
        column.addView(
            top,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        val spacer = View(this)
        column.addView(
            spacer,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        )

        val bottom = LinearLayout(this)
        bottom.orientation = LinearLayout.HORIZONTAL
        bottom.gravity = Gravity.CENTER
        bottom.addView(button("⏪", density) { seekBy(-10_000) })
        val play = button("⏸", density) { togglePlay() }
        playButton = play
        bottom.addView(play)
        bottom.addView(button("⏩", density) { seekBy(10_000) })
        val speed = button("1x", density) { cycleSpeed() }
        speedButton = speed
        bottom.addView(speed)
        val mute = button("🔊", density) { toggleMute() }
        muteButton = mute
        bottom.addView(mute)
        column.addView(
            bottom,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        val bar = SeekBar(this)
        bar.max = 1
        bar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(
                seekBar: SeekBar?,
                progress: Int,
                fromUser: Boolean
            ) {
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {
                dragging = true
            }

            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                dragging = false
                try {
                    player?.seekTo(seekBar?.progress ?: 0)
                } catch (e: Exception) {
                }
            }
        })
        seekBar = bar
        column.addView(
            bar,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
        controls = column
        return column
    }

    private fun button(text: String, density: Float, onTap: () -> Unit): TextView {
        val view = TextView(this)
        view.text = text
        view.setTextColor(Color.WHITE)
        view.textSize = 15f
        val pad = (10 * density).toInt()
        view.setPadding(pad, pad / 2, pad, pad / 2)
        view.setOnClickListener { onTap() }
        return view
    }

    /**
     * Sürükleme + köşeden boyutlandırma + çift dokunuşla hazır boylar.
     *
     * Boyutlandırma için ayrı bir tutamak yerine **sağ alt çeyrek**
     * kullanılıyor: 220 dp'lik bir pencerede ayrı tutamak parmakla
     * vurulamayacak kadar küçük kalırdı.
     */
    private fun attachDrag(
        view: View,
        params: WindowManager.LayoutParams,
        density: Float
    ) {
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        var resizing = false
        var moved = false
        var lastTap = 0L
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    resizing = event.x > view.width * 0.75f &&
                        event.y > view.height * 0.75f
                    val now = System.currentTimeMillis()
                    if (now - lastTap < 300) cycleSize(params, density)
                    lastTap = now
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    // Parmak kaymasını dokunuş sanmamak için eşik: 8 dp'den
                    // azı "taşıma" değil, "dokunma" sayılıyor.
                    if (kotlin.math.abs(dx) + kotlin.math.abs(dy) > 8 * density) {
                        moved = true
                    }
                    if (resizing) {
                        val width = (params.width + dx).coerceIn(
                            (140 * density).toInt(),
                            resources.displayMetrics.widthPixels
                        )
                        params.width = width
                        params.height = (width * videoHeight / videoWidth)
                        touchX = event.rawX
                        touchY = event.rawY
                    } else {
                        params.x = startX + dx
                        params.y = startY + dy
                    }
                    try {
                        windowManager?.updateViewLayout(view, params)
                    } catch (e: Exception) {
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // **Yalnız TAŞIMA DEĞİLSE** denetimleri çevir: pencereyi
                    // sürükledikten sonra düğmelerin kaybolması (ya da
                    // belirmesi) kullanıcıya hata gibi görünüyordu.
                    if (!moved) {
                        controls?.visibility =
                            if (controls?.visibility == View.VISIBLE) View.GONE
                            else View.VISIBLE
                    }
                    true
                }
                else -> false
            }
        }
    }

    /** Küçük → orta → büyük (ekran genişliğinin %40/%60/%85'i). */
    private fun cycleSize(params: WindowManager.LayoutParams, density: Float) {
        sizeStep = (sizeStep + 1) % 3
        val screen = resources.displayMetrics.widthPixels
        val fraction = when (sizeStep) {
            0 -> 0.40f
            1 -> 0.60f
            else -> 0.85f
        }
        params.width = (screen * fraction).toInt()
        params.height = params.width * videoHeight / videoWidth
        try {
            windowManager?.updateViewLayout(root, params)
        } catch (e: Exception) {
        }
    }

    // ── Oynatma ───────────────────────────────────────────────────────────

    private fun openMedia() {
        releasePlayer()
        val source = path ?: return
        val mp = MediaPlayer()
        player = mp
        try {
            mp.setDataSource(source)
            surface?.holder?.let { mp.setDisplay(it) }
            mp.setOnVideoSizeChangedListener { _, width, height ->
                if (width > 0 && height > 0) {
                    videoWidth = width
                    videoHeight = height
                    resizeToAspect()
                }
            }
            mp.setOnPreparedListener {
                prepared = true
                seekBar?.max = if (mp.duration > 0) mp.duration else 1
                if (pendingSeek > 0) {
                    try {
                        mp.seekTo(pendingSeek.toInt())
                    } catch (e: Exception) {
                    }
                }
                mp.start()
                playButton?.text = "⏸"
            }
            mp.setOnCompletionListener {
                playButton?.text = "▶"
            }
            mp.setOnErrorListener { _, _, _ ->
                // Çözülemeyen biçim: pencereyi kapat, kullanıcı uygulamada
                // (ExoPlayer ile) açmayı sürdürebilsin.
                closeWindow()
                true
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            closeWindow()
        }
    }

    /** Pencereyi videonun en-boy oranına oturtur (siyah şerit kalmasın). */
    private fun resizeToAspect() {
        val view = root ?: return
        val params = view.layoutParams as? WindowManager.LayoutParams ?: return
        params.height = params.width * videoHeight / videoWidth
        try {
            windowManager?.updateViewLayout(view, params)
        } catch (e: Exception) {
        }
    }

    private fun togglePlay() {
        val mp = player ?: return
        try {
            if (mp.isPlaying) {
                mp.pause()
                playButton?.text = "▶"
            } else {
                mp.start()
                playButton?.text = "⏸"
            }
        } catch (e: Exception) {
        }
    }

    private fun seekBy(deltaMs: Int) {
        val mp = player ?: return
        try {
            val target = (mp.currentPosition + deltaMs)
                .coerceIn(0, if (mp.duration > 0) mp.duration else 0)
            mp.seekTo(target)
        } catch (e: Exception) {
        }
    }

    private fun cycleSpeed() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val mp = player ?: return
        speedIndex = (speedIndex + 1) % speeds.size
        val value = speeds[speedIndex]
        try {
            val wasPlaying = mp.isPlaying
            mp.playbackParams = mp.playbackParams.setSpeed(value)
            // `playbackParams` atamak duraklatılmış bir oynatıcıyı BAŞLATIR;
            // kullanıcı duraklattıysa öyle kalmalı.
            if (!wasPlaying) mp.pause()
        } catch (e: Exception) {
        }
        speedButton?.text = if (value == 1f) "1x" else "${value}x"
    }

    private fun toggleMute() {
        val mp = player ?: return
        muted = !muted
        try {
            mp.setVolume(if (muted) 0f else 1f, if (muted) 0f else 1f)
        } catch (e: Exception) {
        }
        muteButton?.text = if (muted) "🔇" else "🔊"
    }

    private fun positionMs(): Long = try {
        (player?.currentPosition ?: 0).toLong()
    } catch (e: Exception) {
        0L
    }

    /** Uygulamaya dön: konumu bildir, uygulamayı öne getir, pencereyi kapat. */
    private fun expandToApp() {
        val position = positionMs()
        FloatingBridge.emit("expand", position)
        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (launch != null) startActivity(launch)
        } catch (e: Exception) {
        }
        stopSelf()
    }

    private fun closeWindow() {
        FloatingBridge.emit("closed", positionMs())
        stopSelf()
    }

    private fun releasePlayer() {
        prepared = false
        val mp = player ?: return
        player = null
        try {
            mp.stop()
        } catch (e: Exception) {
        }
        try {
            mp.release()
        } catch (e: Exception) {
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        releasePlayer()
        val view = root
        root = null
        if (view != null) {
            try {
                windowManager?.removeView(view)
            } catch (e: Exception) {
            }
        }
        FloatingBridge.running = false
        try {
            if (Build.VERSION.SDK_INT >= 24) {
                stopForeground(Service.STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Exception) {
        }
        super.onDestroy()
    }
}
