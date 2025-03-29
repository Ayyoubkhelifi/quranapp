package com.example.quranapp

class Application : android.app.Application() {
    override fun onCreate() {
        super.onCreate()
        
        // Log initialization
        android.util.Log.d("QuranApp", "Application initialized")
    }
} 