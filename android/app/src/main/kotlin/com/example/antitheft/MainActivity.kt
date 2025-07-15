package com.example.antitheft

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.AudioManager
import android.media.RingtoneManager
import android.media.RingtoneManager.TYPE_RINGTONE
import android.media.RingtoneManager.TYPE_NOTIFICATION
import android.media.RingtoneManager.TYPE_ALARM
import android.media.Ringtone
import android.content.ContentValues
import android.provider.MediaStore
import android.net.Uri
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "antitheft_service"
    private var pendingRingtoneFileName: String? = null
    private var pendingRingtoneResult: MethodChannel.Result? = null
    companion object {
        var selectedAudioFile: String = "alarm.wav"
        var selectedLoop: String = "infinite"
        var selectedVibrate: Boolean = false
        var selectedFlash: Boolean = false
        var pickpocketMode: Boolean = false
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
                    val flash = call.argument<Boolean>("flash") ?: false
                    selectedAudioFile = fileName
                    selectedLoop = loop
                    selectedVibrate = vibrate
                    selectedFlash = flash
                    // Reload audio in the service if it's running
                    val intent = Intent(this, AntiTheftService::class.java)
                    intent.action = "RELOAD_AUDIO"
                    startForegroundService(intent)
                    result.success(null)
                }
                "setPickpocketMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    pickpocketMode = enabled
                    result.success(null)
                }
                "getSystemVolume" -> {
                    val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                    val volume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    result.success(volume.toDouble() / max)
                }
                "setSystemVolume" -> {
                    val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                    val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val volume = (call.argument<Double>("volume") ?: 0.5) * max
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume.toInt(), 0)
                    result.success(null)
                }
                "setRingtone" -> {
                    val fileName = call.argument<String>("fileName") ?: "alarm.wav"
                    // Check and request permissions only when setting ringtone
                    val writeSettingsGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.provider.Settings.System.canWrite(this) else true
                    // Only check WRITE_EXTERNAL_STORAGE for Android 9 and below
                    if (!writeSettingsGranted) {
                        result.error("PERMISSION_DENIED", "Please grant Modify System Settings permission and try again.", null)
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        val writeStorageGranted = ActivityCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                        if (!writeStorageGranted) {
                            result.error("PERMISSION_DENIED", "Please grant Storage permission and try again.", null)
                            return@setMethodCallHandler
                        }
                    }
                    try {
                        // Use res/raw for native audio files
                        val fileNameWithoutExtension = fileName.substringBeforeLast('.')
                        val resId = resources.getIdentifier(fileNameWithoutExtension, "raw", packageName)
                        if (resId == 0) throw Exception("Resource not found: $fileNameWithoutExtension")
                        val inputStream: InputStream = resources.openRawResource(resId)
                        val outFile = File(externalCacheDir, fileName)
                        val outputStream = FileOutputStream(outFile)
                        inputStream.copyTo(outputStream)
                        inputStream.close()
                        outputStream.close()
                        val values = ContentValues().apply {
                            put(MediaStore.MediaColumns.TITLE, fileName)
                            put(MediaStore.MediaColumns.MIME_TYPE, "audio/ogg")
                            put(MediaStore.MediaColumns.SIZE, outFile.length())
                            put(MediaStore.Audio.Media.IS_RINGTONE, true)
                            put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                            put(MediaStore.Audio.Media.IS_ALARM, false)
                            put(MediaStore.Audio.Media.IS_MUSIC, false)
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                                put(MediaStore.MediaColumns.DATA, outFile.absolutePath)
                            }
                        }
                        val uri = MediaStore.Audio.Media.getContentUriForPath(outFile.absolutePath)
                        val newUri = contentResolver.insert(uri!!, values)
                        RingtoneManager.setActualDefaultRingtoneUri(this, TYPE_RINGTONE, newUri)
                        result.success("Ringtone set!")
                    } catch (e: Exception) {
                        result.error("RINGTONE_ERROR", e.message, null)
                    }
                }
                "hasWriteSettingsPermission" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.provider.Settings.System.canWrite(this) else true
                    result.success(granted)
                }
                "openWriteSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(android.provider.Settings.ACTION_MANAGE_WRITE_SETTINGS)
                        intent.data = Uri.parse("package:" + packageName)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Remove pendingRingtoneFileName and onRequestPermissionsResult logic, as permission is now handled in Dart
}
