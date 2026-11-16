package com.example.synk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pictures and links shared to Synk (ShareActivity.kt).
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "synk/shared")
        SharedItems.onAdded = { channel.invokeMethod("added", null) }
        channel.setMethodCallHandler { call, result ->
            if (call.method == "take") {
                result.success(SharedItems.take())
            } else {
                result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        SharedItems.onAdded = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
