package com.sophis.sophis

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var paddleOcr: AutoCloseable? = null
    private var scanModels: ScanModelInstaller? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        paddleOcr = PaddleOcrPlugin.register(this, flutterEngine.dartExecutor.binaryMessenger)
        scanModels = ScanModelInstaller(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sophis/scan_models")
            .setMethodCallHandler { call, result ->
                if (call.method == "ensureAvailable") {
                    scanModels?.ensureAvailable(call.argument<String>("model"), result)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        paddleOcr?.close()
        scanModels?.close()
        super.onDestroy()
    }
}
