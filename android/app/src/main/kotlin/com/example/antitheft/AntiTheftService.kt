package com.example.antitheft

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Handler

class AntiTheftService : Service(), SensorEventListener {
    private val LOG_TAG = "ANTITHEFT_DEBUG"
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var isArmed = false
    private var alarming = false
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val threshold = 12.0f
    private val cooldownMillis = 2000L
    private var lastTrigger = 0L
    private var sensorRegistered = false
    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "antitheft_service"

    override fun onCreate() {
        super.onCreate()
        android.util.Log.i(LOG_TAG, "Service onCreate called")
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        createOrInitMediaPlayer()
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AntiTheft::Wakelock")
        createNotificationChannel()
    }

    private fun createOrInitMediaPlayer() {
        try {
            mediaPlayer?.release()
            val resId = getAudioResId(MainActivity.selectedAudioFile)
            mediaPlayer = MediaPlayer.create(this, resId)
            if (mediaPlayer == null) {
                android.util.Log.e(LOG_TAG, "MediaPlayer creation FAILED for ${MainActivity.selectedAudioFile}")
            } else {
                android.util.Log.i(LOG_TAG, "MediaPlayer created for ${MainActivity.selectedAudioFile}")
                mediaPlayer?.setOnErrorListener { mp, what, extra ->
                    android.util.Log.e(LOG_TAG, "MediaPlayer ERROR: what=$what, extra=$extra")
                    false
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(LOG_TAG, "Exception during MediaPlayer creation: ${e.message}")
        }
    }

    private fun getAudioResId(fileName: String): Int {
        return when (fileName) {
            "alarm.wav" -> R.raw.alarm
            "alarm2.flac" -> R.raw.alarm2
            "alert.wav" -> R.raw.alert
            "bark.wav" -> R.raw.bark
            "police.mp3" -> R.raw.police
            "siren.wav" -> R.raw.siren
            "siren2.wav" -> R.raw.siren2
            else -> R.raw.alarm
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.i(LOG_TAG, "Service onStartCommand called")
        // Show correct notification based on state
        if (alarming) {
            startForeground(NOTIFICATION_ID, buildNotification("\uD83D\uDEA8 ALARM TRIGGERED! \uD83D\uDEA8", showStop = true))
        } else if (isArmed) {
            startForeground(NOTIFICATION_ID, buildNotification("Anti-Theft Service is active"))
        } else {
            startForeground(NOTIFICATION_ID, buildNotification("Anti-Theft Monitoring Paused (Disarmed)"))
        }
        wakeLock?.acquire()
        if (!sensorRegistered) {
            registerSensorWithRetry()
        }
        when (intent?.action) {
            "ARM" -> {
                isArmed = true
                android.util.Log.i(LOG_TAG, "Service ARMED")
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, buildNotification("Anti-Theft Service is active"))
            }
            "DISARM" -> {
                isArmed = false
                alarming = false
                mediaPlayer?.pause()
                mediaPlayer?.seekTo(0)
                // Stop vibration safely
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (vibrator != null && vibrator.hasVibrator()) {
                    vibrator.cancel()
                }
                android.util.Log.i(LOG_TAG, "Service DISARMED")
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, buildNotification("Anti-Theft Monitoring Paused (Disarmed)"))
            }
            "STOP_ALARM" -> {
                alarming = false
                mediaPlayer?.pause()
                mediaPlayer?.seekTo(0)
                isArmed = false
                // Stop vibration safely
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (vibrator != null && vibrator.hasVibrator()) {
                    vibrator.cancel()
                }
                android.util.Log.i(LOG_TAG, "Alarm stopped by notification action")
                stopForeground(true) // Remove the notification immediately
                MainActivity.notifyFlutterDisarmed() // Notify Flutter to update toggle
                // No disarmed notification
            }
        }
        return START_STICKY;
    }

    private fun registerSensorWithRetry(retries: Int = 3) {
        sensorRegistered = false
        for (i in 1..retries) {
            if (accelerometer == null) {
                android.util.Log.e(LOG_TAG, "Accelerometer sensor is NULL! Retry $i/$retries")
                continue
            }
            sensorRegistered = sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
            if (sensorRegistered) {
                android.util.Log.i(LOG_TAG, "Sensor registered successfully on attempt $i")
                break
            } else {
                android.util.Log.e(LOG_TAG, "Sensor registration FAILED on attempt $i/$retries")
                Thread.sleep(200)
            }
        }
        if (!sensorRegistered) {
            android.util.Log.e(LOG_TAG, "Sensor registration ultimately FAILED. Notifying user.")
            showSensorFailureNotification()
        }
    }

    private fun showSensorFailureNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Anti-Theft Monitoring Error")
            .setContentText("Unable to access device sensors. Anti-theft monitoring is not active.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(true)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID + 1, notification)
    }

    override fun onDestroy() {
        android.util.Log.i(LOG_TAG, "Service onDestroy called")
        if (sensorRegistered) sensorManager.unregisterListener(this)
        mediaPlayer?.release()
        wakeLock?.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent?) {
        if (!isArmed || event == null) return
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val magnitude = sqrt(x * x + y * y + z * z)
        val now = System.currentTimeMillis()
        if (magnitude > threshold && !alarming && now - lastTrigger > cooldownMillis) {
            alarming = true
            lastTrigger = now
            android.util.Log.i(LOG_TAG, "ALARM TRIGGERED: magnitude=$magnitude, playing sound")
            if (mediaPlayer == null) {
                android.util.Log.e(LOG_TAG, "MediaPlayer is NULL at alarm trigger, re-initializing")
                createOrInitMediaPlayer()
            }
            try {
                mediaPlayer?.isLooping = true
                mediaPlayer?.start()
                mediaPlayer?.setOnCompletionListener { alarming = false; android.util.Log.i(LOG_TAG, "Alarm sound completed") }
                // Vibrate if enabled
                if (MainActivity.selectedVibrate) {
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                    if (vibrator != null && vibrator.hasVibrator()) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 500, 500), 0))
                        } else {
                            vibrator.vibrate(longArrayOf(0, 500, 500, 500), 0)
                        }
                    }
                }
                // Handle loop duration
                if (MainActivity.selectedLoop != "infinite") {
                    val durationMs = when (MainActivity.selectedLoop) {
                        "30s" -> 30_000L
                        "1m" -> 60_000L
                        "2m" -> 120_000L
                        else -> 60_000L
                    }
                    Handler(mainLooper).postDelayed({
                        alarming = false
                        mediaPlayer?.pause()
                        mediaPlayer?.seekTo(0)
                        // Stop vibration safely
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                        if (vibrator != null && vibrator.hasVibrator()) {
                            vibrator.cancel()
                        }
                        // Update notification
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.notify(NOTIFICATION_ID, buildNotification("Anti-Theft Service is active"))
                    }, durationMs)
                }
                // Update notification to ALARM TRIGGERED with stop button
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, buildNotification("\uD83D\uDEA8 ALARM TRIGGERED! \uD83D\uDEA8", showStop = true))
            } catch (e: Exception) {
                android.util.Log.e(LOG_TAG, "Exception during mediaPlayer.start(): ${e.message}")
            }
        }
    }

    private fun buildNotification(contentText: String, showStop: Boolean = false): Notification {
        val mainIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, mainIntent, PendingIntent.FLAG_IMMUTABLE)
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Anti-Theft Service")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
        if (showStop) {
            val stopIntent = Intent(this, AntiTheftService::class.java)
            stopIntent.action = "STOP_ALARM"
            val stopPendingIntent = PendingIntent.getService(
                this, 1, stopIntent, PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_media_pause, "Stop Alarm", stopPendingIntent)
        }
        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Anti-Theft Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Shows status of anti-theft monitoring"
            channel.setShowBadge(true)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
} 