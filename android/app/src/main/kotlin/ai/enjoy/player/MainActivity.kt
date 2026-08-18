package ai.enjoy.player

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ESPEAK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeLibraryDir" ->
                    result.success(applicationInfo.nativeLibraryDir)
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val ESPEAK_CHANNEL = "ai.enjoy.player/espeak"
    }
}
