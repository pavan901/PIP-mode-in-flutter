package com.example.quick_start
import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Rational

class PiPService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPiPMode()
        }
        return START_NOT_STICKY
    }

    private fun enterPiPMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            MainActivity.instance?.enterPictureInPictureMode(params)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
