package com.operondriverandroid.app

import com.operon.updater.AppUpdater
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

	companion object {
		private const val UPDATE_CHANNEL = "operon.app/app_updater"
		private const val DEFAULT_UPDATE_URL = "https://api.operon.com/updates/{app_name}.json"
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"checkUpdate" -> {
						val url = call.arguments as? String ?: DEFAULT_UPDATE_URL
						AppUpdater.with(this).check(url)
						result.success(null)
					}
					"hasInstallPermission" -> {
						val hasPermission = AppUpdater.with(this).hasInstallPermission(this)
						result.success(hasPermission)
					}
					"requestInstallPermission" -> {
						AppUpdater.with(this).requestInstallPermission(this)
						result.success(null)
					}
					else -> result.notImplemented()
				}
			}
	}
}

