package com.antitheft.alarm.phone.alarm.touch.alarm

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
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val CHANNEL = "antitheft_service"
    private var pendingRingtoneFileName: String? = null
    private var pendingRingtoneResult: MethodChannel.Result? = null
    companion object {
        var selectedAudioFile: String = "alarm2.ogg"
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
                    val fileName = call.argument<String>("fileName") ?: "alarm2.ogg"
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
                    val fileName = call.argument<String>("fileName") ?: "alarm2.ogg"
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
                "scheduleAutoDisarm" -> {
                    val hour = call.argument<Int>("hour") ?: 9
                    val minute = call.argument<Int>("minute") ?: 0
                    scheduleAutoDisarmAlarm(hour, minute)
                    result.success(null)
                }
                "cancelAutoDisarm" -> {
                    cancelAutoDisarmAlarm()
                    result.success(null)
                }
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "openExactAlarmSettings" -> {
                    openExactAlarmSettings()
                    result.success(null)
                }
                "serviceIsRunning" -> {
                    val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val running = manager.getRunningServices(Int.MAX_VALUE)
                        .any { it.service.className == AntiTheftService::class.java.name }
                    result.success(running)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleAutoDisarmAlarm(hour: Int, minute: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AutoDisarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val now = java.util.Calendar.getInstance()
        val target = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            if (before(now)) add(java.util.Calendar.DATE, 1)
        }
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pendingIntent)
    }

    private fun cancelAutoDisarmAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AutoDisarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager.cancel(pendingIntent)
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun openExactAlarmSettings() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }
}

class AutoDisarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, AntiTheftService::class.java)
        serviceIntent.action = "DISARM"
        context.startService(serviceIntent)
        // Optionally, notify Flutter via method channel if app is running
        MainActivity.methodChannel?.invokeMethod("disarmedByNotification", null)
    }
}
