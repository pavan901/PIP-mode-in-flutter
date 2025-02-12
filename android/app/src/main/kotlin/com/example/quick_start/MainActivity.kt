package com.example.quick_start

import android.app.PictureInPictureParams
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    companion object {
        var instance: MainActivity? = null
    }

    private val CHANNEL = "pip_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enterPiPMode") {
                Log.d("MainActivity", "enterPiPMode");
                startPiPService()
                result.success(null)
            }
            else {
                result.notImplemented()
            }
        }
    }


    private fun startPiPService() {
        Log.d("MainActivity", "startPiPService")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val paramsBuilder = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                
            // Only set auto-enter for Android 12 and above
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                paramsBuilder.setAutoEnterEnabled(true)
            }
            
            this.enterPictureInPictureMode(paramsBuilder.build())
        }
    }
}
