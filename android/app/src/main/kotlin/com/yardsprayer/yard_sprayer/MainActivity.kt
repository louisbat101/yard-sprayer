package com.yardsprayer.yard_sprayer

import android.annotation.SuppressLint
import android.content.Context
import android.location.LocationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var gnssChannel: MethodChannel? = null
    private var locationManager: LocationManager? = null
    private var listening = false

    @SuppressLint("MissingPermission")
    private fun onGpsStatus(event: Int) {
        val status = locationManager?.getGpsStatus(null) ?: return
        var visible = 0
        var used = 0
        for (satellite in status.satellites) {
            visible++
            if (satellite.usedInFix()) used++
        }
        gnssChannel?.invokeMethod("onSatellites", mapOf("visible" to visible, "used" to used))
    }

    @SuppressLint("MissingPermission")
    private fun startListening() {
        if (listening) return
        try {
            locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            locationManager?.addGpsStatusListener(this::onGpsStatus)
            listening = true
        } catch (_: Exception) {
            // Permission not granted or no GPS provider yet; start again later.
        }
    }

    private fun stopListening() {
        try {
            locationManager?.removeGpsStatusListener(this::onGpsStatus)
        } catch (_: Exception) {
            // ignore
        }
        listening = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        gnssChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yard_sprayer/gnss")
        gnssChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startListening()
                    result.success(null)
                }
                "stop" -> {
                    stopListening()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopListening()
        super.onDestroy()
    }
}
