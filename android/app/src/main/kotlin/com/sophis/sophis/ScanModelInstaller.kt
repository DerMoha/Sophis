package com.sophis.sophis

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.OptionalModuleApi
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate.InstallState
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodChannel

/** Wait for actual installation, rather than treating an accepted request as ready. */
class ScanModelInstaller(private val context: Context) {
    private val pending = mutableSetOf<(String?) -> Unit>()

    fun ensureAvailable(model: String?, result: MethodChannel.Result) {
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context)
            != ConnectionResult.SUCCESS) {
            result.error("play_services_unavailable", "Google Play services is unavailable", null)
            return
        }
        val api: OptionalModuleApi
        val closeApi: () -> Unit
        when (model) {
            "ocr" -> {
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                api = recognizer
                closeApi = { recognizer.close() }
            }
            "barcode" -> {
                val scanner = BarcodeScanning.getClient()
                api = scanner
                closeApi = { scanner.close() }
            }
            else -> {
                result.error("invalid_model", "Unknown scanning model", null)
                return
            }
        }
        val client = ModuleInstall.getClient(context)
        val handler = Handler(Looper.getMainLooper())
        var completed = false
        lateinit var listener: InstallStatusListener
        lateinit var timeout: Runnable
        lateinit var finish: (String?) -> Unit
        finish = { error ->
            if (!completed) {
                completed = true
                handler.removeCallbacks(timeout)
                client.unregisterListener(listener)
                closeApi()
                pending.remove(finish)
                if (error == null) result.success(null)
                else result.error(error, "Scanning model could not be prepared", null)
            }
        }
        listener = InstallStatusListener { update ->
            when (update.installState) {
                InstallState.STATE_COMPLETED -> finish(null)
                InstallState.STATE_FAILED, InstallState.STATE_CANCELED -> finish("download_failed")
            }
        }
        timeout = Runnable { finish("download_timeout") }
        pending.add(finish)
        handler.postDelayed(timeout, 60_000)
        client.areModulesAvailable(api)
            .addOnSuccessListener { availability ->
                if (!completed) {
                    if (availability.areModulesAvailable()) {
                        finish(null)
                    } else {
                        val request = ModuleInstallRequest.newBuilder()
                            .addApi(api).setListener(listener).build()
                        client.installModules(request)
                            .addOnSuccessListener { response ->
                                if (response.areModulesAlreadyInstalled()) finish(null)
                            }
                            .addOnFailureListener { finish("download_failed") }
                    }
                }
            }
            .addOnFailureListener { finish("download_failed") }
    }

    fun close() {
        pending.toList().forEach { it("activity_closed") }
    }
}
