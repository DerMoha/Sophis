package com.sophis.sophis

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** A normal build never loads or packages the experimental native runtime. */
object PaddleOcrPlugin {
    fun register(context: Context, messenger: BinaryMessenger): AutoCloseable {
        val channel = MethodChannel(messenger, "sophis/paddle_ocr")
        channel.setMethodCallHandler { _, result ->
            result.error("paddle_not_built", "PaddleOCR is not enabled in this Android build.", null)
        }
        return AutoCloseable { channel.setMethodCallHandler(null) }
    }
}
