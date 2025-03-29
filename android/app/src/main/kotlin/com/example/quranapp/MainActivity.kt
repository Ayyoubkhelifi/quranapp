package com.example.quranapp

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.os.Bundle
import android.content.Context
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    companion object {
        // Static reference to current activity instance that plugins can access
        @JvmStatic
        var currentActivity: MainActivity? = null
            private set
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Store reference to this activity
        currentActivity = this
    }
    
    override fun onResume() {
        super.onResume()
        // Update the current activity reference
        currentActivity = this
    }
    
    override fun onDestroy() {
        // Only clear the reference if this is the stored activity
        if (currentActivity === this) {
            currentActivity = null
        }
        super.onDestroy()
    }
}
