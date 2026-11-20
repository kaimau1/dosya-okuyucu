package com.dosyaokuyucu.dosya_okuyucu

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Play İçi Değerlendirme + Uygulama İçi Güncelleme (KALANLAR A6.6, N5).
 *
 * YALNIZ Play AAB'sine girer (`ci/play_core.sh`, `DOSYA_PLAY=1`): GitHub APK'sı
 * Play kütüphanelerini taşımaz. MainActivity bu sınıfı ADIYLA (yansımayla)
 * arar; yoksa kanal hiç kurulmaz ve Dart `MissingPluginException` görür.
 */
object PlayCore {
    const val CHANNEL = "dosya/play"
    private const val UPDATE_REQUEST = 7371

    private var updates: AppUpdateManager? = null
    private var listener: InstallStateUpdatedListener? = null

    @JvmStatic
    fun detach() {
        val m = updates
        val l = listener
        updates = null
        listener = null
        if (m != null && l != null) {
            try { m.unregisterListener(l) } catch (_: Exception) {}
        }
    }

    @JvmStatic
    fun attach(activity: Activity, messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL)
        val manager = AppUpdateManagerFactory.create(activity)
        detach()
        updates = manager
        val l = InstallStateUpdatedListener { state ->
            if (state.installStatus() == InstallStatus.DOWNLOADED) {
                activity.runOnUiThread {
                    try { channel.invokeMethod("downloaded", null) } catch (_: Exception) {}
                }
            }
        }
        listener = l
        manager.registerListener(l)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "available" -> result.success(true)
                    "requestReview" -> {
                        val review = ReviewManagerFactory.create(activity)
                        review.requestReviewFlow().addOnCompleteListener { req ->
                            try {
                                if (!req.isSuccessful) {
                                    result.success(false)
                                } else {
                                    review.launchReviewFlow(activity, req.result)
                                        .addOnCompleteListener { result.success(true) }
                                }
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "checkUpdate" -> manager.appUpdateInfo
                        .addOnSuccessListener { info ->
                            result.success(
                                mapOf(
                                    "available" to (info.updateAvailability() ==
                                        UpdateAvailability.UPDATE_AVAILABLE),
                                    "inProgress" to (info.updateAvailability() ==
                                        UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS),
                                    "flexible" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                                    "immediate" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                                    "downloaded" to (info.installStatus() == InstallStatus.DOWNLOADED),
                                    "staleDays" to (info.clientVersionStalenessDays() ?: -1),
                                    "priority" to info.updatePriority(),
                                    "versionCode" to info.availableVersionCode(),
                                )
                            )
                        }
                        .addOnFailureListener { result.success(null) }
                    "startUpdate" -> {
                        val type = if (call.argument<Boolean>("immediate") == true)
                            AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
                        manager.appUpdateInfo
                            .addOnSuccessListener { info ->
                                try {
                                    if (!info.isUpdateTypeAllowed(type)) {
                                        result.success(false)
                                    } else {
                                        @Suppress("DEPRECATION")
                                        val ok = manager.startUpdateFlowForResult(
                                            info, activity,
                                            AppUpdateOptions.defaultOptions(type), UPDATE_REQUEST
                                        )
                                        result.success(ok)
                                    }
                                } catch (_: Exception) {
                                    result.success(false)
                                }
                            }
                            .addOnFailureListener { result.success(false) }
                    }
                    "completeUpdate" -> {
                        manager.completeUpdate()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("play", e.message, null)
            }
        }
    }
}
