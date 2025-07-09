package com.example.antitheft

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "antitheft_service"
    companion object {
        var selectedAudioFile: String = "alarm.wav"
        var selectedLoop: String = "infinite"
        var selectedVibrate: Boolean = false
        var methodChannel: MethodChannel? = null
        fun notifyFlutterDisarmed() {
            methodChannel?.invokeMethod("disarmedByNotification", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            val intent = Intent(this, AntiTheftService::class.java)
            when (call.method) {
                "startService" -> {
                    startForegroundService(intent)
                    result.success(null)
                }
                "stopService" -> {
                    stopService(intent)
                    result.success(null)
                }
                "arm" -> {
                    intent.action = "ARM"
                    startForegroundService(intent)
                    result.success(null)
                }
                "disarm" -> {
                    intent.action = "DISARM"
                    startForegroundService(intent)
                    result.success(null)
                }
                "setAudio" -> {
                    val fileName = call.argument<String>("fileName") ?: "alarm.wav"
                    val loop = call.argument<String>("loop") ?: "infinite"
                    val vibrate = call.argument<Boolean>("vibrate") ?: false
                    selectedAudioFile = fileName
                    selectedLoop = loop
                    selectedVibrate = vibrate
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
