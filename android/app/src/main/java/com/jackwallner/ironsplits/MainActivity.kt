package com.jackwallner.ironsplits

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.setContent
import com.jackwallner.ironsplits.ui.IronSplitsApp
import com.jackwallner.ironsplits.ui.IronSplitsTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            IronSplitsTheme {
                IronSplitsApp()
            }
        }
    }
}
