package com.kreativekoala.sayitai.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Overlay shown when a feature requires internet but the device is offline.
 * Matches the iOS OfflineUnavailableOverlay for feature parity.
 */
@Composable
fun OfflineUnavailableOverlay(
    feature: String,
    suggestion: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.85f)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(32.dp)
        ) {
            // WiFi Off Icon
            Icon(
                imageVector = Icons.Default.WifiOff,
                contentDescription = "Offline",
                modifier = Modifier.size(60.dp),
                tint = Color(0xFFFFA500) // Orange
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Title
            Text(
                text = "$feature Unavailable",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Description
            Text(
                text = "This feature requires an internet connection.",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Suggestion Box
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = Color.White.copy(alpha = 0.1f),
                modifier = Modifier.padding(horizontal = 20.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Lightbulb,
                        contentDescription = "Tip",
                        tint = Color.Yellow,
                        modifier = Modifier.size(20.dp)
                    )

                    Text(
                        text = suggestion,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.9f),
                        modifier = Modifier.padding(start = 8.dp)
                    )
                }
            }
        }
    }
}

/**
 * Compact offline indicator banner for showing at the top of screens
 */
@Composable
fun OfflineBanner(
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        color = Color(0xFFFFA500), // Orange
        shape = RoundedCornerShape(bottomStart = 8.dp, bottomEnd = 8.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.WifiOff,
                contentDescription = "Offline",
                modifier = Modifier.size(16.dp),
                tint = Color.White
            )

            Text(
                text = "Offline Mode",
                style = MaterialTheme.typography.labelMedium,
                color = Color.White,
                modifier = Modifier.padding(start = 8.dp)
            )
        }
    }
}

/**
 * Small offline indicator icon with text
 */
@Composable
fun OfflineIndicator(
    modifier: Modifier = Modifier,
    showText: Boolean = true
) {
    Row(
        modifier = modifier
            .background(
                color = Color(0xFFFFA500).copy(alpha = 0.2f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.WifiOff,
            contentDescription = "Offline",
            modifier = Modifier.size(14.dp),
            tint = Color(0xFFFFA500)
        )

        if (showText) {
            Text(
                text = "Offline",
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFFFFA500),
                modifier = Modifier.padding(start = 4.dp)
            )
        }
    }
}

// Previews

@Preview(showBackground = true)
@Composable
private fun OfflineUnavailableOverlayPreview() {
    OfflineUnavailableOverlay(
        feature = "Text Translation",
        suggestion = "Use Voice tab for offline translation"
    )
}

@Preview(showBackground = true)
@Composable
private fun OfflineBannerPreview() {
    OfflineBanner()
}

@Preview(showBackground = true)
@Composable
private fun OfflineIndicatorPreview() {
    OfflineIndicator()
}
