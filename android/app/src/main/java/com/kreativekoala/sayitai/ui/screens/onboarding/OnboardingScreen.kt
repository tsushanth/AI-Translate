package com.kreativekoala.sayitai.ui.screens.onboarding

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.kreativekoala.sayitai.ui.theme.Primary
import com.kreativekoala.sayitai.util.DeviceCapabilityChecker
import com.kreativekoala.sayitai.util.OfflineCapability
import com.kreativekoala.sayitai.util.OfflineModelPackage
import com.kreativekoala.sayitai.util.PerformanceEstimate
import kotlinx.coroutines.launch

data class OnboardingPage(
    val icon: ImageVector,
    val title: String,
    val description: String,
    val color: Color
)

val onboardingPages = listOf(
    OnboardingPage(
        icon = Icons.Default.Translate,
        title = "Instant Translation",
        description = "Translate text between 30+ languages with high accuracy using Google Translate or DeepL.",
        color = Primary
    ),
    OnboardingPage(
        icon = Icons.Default.Mic,
        title = "Voice Conversations",
        description = "Have real-time conversations with automatic speech recognition and translation.",
        color = Color(0xFF34C759)
    ),
    OnboardingPage(
        icon = Icons.Default.CameraAlt,
        title = "Camera Translation",
        description = "Point your camera at any text to instantly translate signs, menus, and documents.",
        color = Color(0xFFFF9500)
    ),
    OnboardingPage(
        icon = Icons.Default.VolumeUp,
        title = "Natural Voices",
        description = "Hear translations spoken aloud with natural-sounding AI voices.",
        color = Color(0xFF5856D6)
    )
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
    deviceCapabilityChecker: DeviceCapabilityChecker
) {
    val offlineCapability = deviceCapabilityChecker.offlineCapability
    val supportsOfflineMode = offlineCapability.supportsOfflineMode

    // Total pages: value props + (offline setup if supported) + pricing
    val totalPages = onboardingPages.size + (if (supportsOfflineMode) 2 else 1)
    val offlineSetupPageIndex = onboardingPages.size
    val pricingPageIndex = if (supportsOfflineMode) onboardingPages.size + 1 else onboardingPages.size

    val pagerState = rememberPagerState(pageCount = { totalPages })
    val coroutineScope = rememberCoroutineScope()

    var selectedPackage by remember { mutableStateOf<OfflineModelPackage?>(null) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.background,
                        MaterialTheme.colorScheme.surface
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Skip button (hidden on pricing/offline setup pages)
            if (pagerState.currentPage < onboardingPages.size) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(
                        onClick = {
                            coroutineScope.launch {
                                pagerState.animateScrollToPage(offlineSetupPageIndex)
                            }
                        }
                    ) {
                        Text("Skip")
                    }
                }
            } else {
                Spacer(modifier = Modifier.height(60.dp))
            }

            // Pager
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { page ->
                when {
                    page < onboardingPages.size -> {
                        OnboardingPageContent(page = onboardingPages[page])
                    }
                    supportsOfflineMode && page == offlineSetupPageIndex -> {
                        OfflineModelSetupContent(
                            deviceCapabilityChecker = deviceCapabilityChecker,
                            selectedPackage = selectedPackage,
                            onPackageSelected = { selectedPackage = it },
                            onContinue = {
                                coroutineScope.launch {
                                    pagerState.animateScrollToPage(pricingPageIndex)
                                }
                            }
                        )
                    }
                    else -> {
                        PaywallContent(
                            canSkipPaywall = supportsOfflineMode,
                            onSkip = {
                                viewModel.completeOnboarding()
                                onComplete()
                            },
                            onSubscribe = {
                                // TODO: Implement subscription
                                viewModel.completeOnboarding()
                                onComplete()
                            }
                        )
                    }
                }
            }

            // Page indicators (only for value prop pages)
            if (pagerState.currentPage < onboardingPages.size) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.Center
                ) {
                    repeat(totalPages) { index ->
                        val color by animateColorAsState(
                            targetValue = if (index == pagerState.currentPage) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
                            },
                            label = "indicator_color"
                        )

                        Box(
                            modifier = Modifier
                                .padding(horizontal = 4.dp)
                                .size(if (index == pagerState.currentPage) 24.dp else 8.dp, 8.dp)
                                .clip(CircleShape)
                                .background(color)
                        )
                    }
                }

                // Next/Continue button
                Button(
                    onClick = {
                        coroutineScope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage + 1)
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 32.dp, vertical = 16.dp)
                        .height(56.dp),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Text(
                        text = if (pagerState.currentPage == onboardingPages.size - 1) "Get Started" else "Continue",
                        style = MaterialTheme.typography.titleMedium
                    )
                }

                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

@Composable
private fun OnboardingPageContent(
    page: OnboardingPage
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(120.dp)
                .clip(CircleShape)
                .background(page.color.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                page.icon,
                contentDescription = null,
                modifier = Modifier.size(60.dp),
                tint = page.color
            )
        }

        Spacer(modifier = Modifier.height(48.dp))

        Text(
            text = page.title,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = page.description,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun OfflineModelSetupContent(
    deviceCapabilityChecker: DeviceCapabilityChecker,
    selectedPackage: OfflineModelPackage?,
    onPackageSelected: (OfflineModelPackage) -> Unit,
    onContinue: () -> Unit
) {
    val offlineCapability = deviceCapabilityChecker.offlineCapability
    val availablePackages = deviceCapabilityChecker.getAvailablePackages()
    val recommendedPackage = deviceCapabilityChecker.getRecommendedPackage()

    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            item {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    // Icon with glow effect
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier.size(100.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(80.dp)
                                .clip(CircleShape)
                                .background(
                                    Brush.linearGradient(
                                        colors = listOf(Color(0xFF34C759), Color(0xFF00C7BE))
                                    )
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.CloudDownload,
                                contentDescription = null,
                                modifier = Modifier.size(40.dp),
                                tint = Color.White
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = "Download Offline Models",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = "Choose how much offline capability you want. You can always change this later in Settings.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                }
            }

            // Device info card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.PhoneAndroid,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(24.dp)
                        )

                        Spacer(modifier = Modifier.width(12.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = deviceCapabilityChecker.deviceName,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = offlineCapability.description,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        Surface(
                            color = if (offlineCapability == OfflineCapability.FULL_SUPPORT)
                                Color(0xFF34C759) else Color(0xFFFF9500),
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Text(
                                text = offlineCapability.displayName,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }

            // Package selection
            item {
                Text(
                    text = "Select a Package",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }

            items(availablePackages) { pkg ->
                PackageOptionCard(
                    modelPackage = pkg,
                    isSelected = selectedPackage == pkg,
                    isRecommended = pkg == recommendedPackage,
                    deviceCapabilityChecker = deviceCapabilityChecker,
                    onClick = { onPackageSelected(pkg) }
                )
            }

            // Performance note for standard support
            if (offlineCapability == OfflineCapability.STANDARD_SUPPORT) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = Color(0xFFFF9500).copy(alpha = 0.1f)
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.Top
                        ) {
                            Icon(
                                Icons.Default.Warning,
                                contentDescription = null,
                                tint = Color(0xFFFF9500),
                                modifier = Modifier.size(24.dp)
                            )

                            Spacer(modifier = Modifier.width(12.dp))

                            Column {
                                Text(
                                    text = "Performance Note",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.SemiBold
                                )
                                Text(
                                    text = "On your device, speech processing may take longer than real-time. For faster results, consider the Essential package.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }

        // Bottom action section
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp)
        ) {
            Button(
                onClick = onContinue,
                enabled = selectedPackage != null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(14.dp)
            ) {
                Text(
                    text = when {
                        selectedPackage == null -> "Select a Package"
                        selectedPackage == OfflineModelPackage.NONE -> "Continue Without Downloading"
                        else -> "Download & Continue"
                    },
                    style = MaterialTheme.typography.titleMedium
                )
            }

            if (selectedPackage != null && selectedPackage != OfflineModelPackage.NONE) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Download size: ${selectedPackage!!.totalSize}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
private fun PackageOptionCard(
    modelPackage: OfflineModelPackage,
    isSelected: Boolean,
    isRecommended: Boolean,
    deviceCapabilityChecker: DeviceCapabilityChecker,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .then(
                if (isSelected) {
                    Modifier.border(2.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(12.dp))
                } else {
                    Modifier
                }
            ),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.Top
        ) {
            // Selection indicator
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .border(
                        width = 2.dp,
                        color = if (isSelected) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.3f),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                if (isSelected) {
                    Box(
                        modifier = Modifier
                            .size(14.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary)
                    )
                }
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = modelPackage.displayName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )

                    if (isRecommended) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Surface(
                            color = Color(0xFF34C759),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "RECOMMENDED",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                fontSize = 9.sp,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    Text(
                        text = modelPackage.totalSize,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Features list
                modelPackage.features.forEach { feature ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(vertical = 2.dp)
                    ) {
                        Icon(
                            Icons.Default.Check,
                            contentDescription = null,
                            tint = Color(0xFF34C759),
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = feature,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Performance estimate
                if (modelPackage != OfflineModelPackage.NONE) {
                    modelPackage.whisperModel?.let { whisperModel ->
                        val estimate = deviceCapabilityChecker.getPerformanceEstimate(whisperModel)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                when (estimate) {
                                    is PerformanceEstimate.RealTime -> Icons.Default.CheckCircle
                                    is PerformanceEstimate.NearRealTime -> Icons.Default.CheckCircle
                                    is PerformanceEstimate.SlowerThanRealTime -> Icons.Default.Warning
                                    is PerformanceEstimate.NotRecommended -> Icons.Default.Cancel
                                },
                                contentDescription = null,
                                tint = when (estimate.statusColor) {
                                    "green" -> Color(0xFF34C759)
                                    "orange" -> Color(0xFFFF9500)
                                    "red" -> Color(0xFFFF3B30)
                                    else -> Color.Gray
                                },
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Speed: ${estimate.displayText}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PaywallContent(
    canSkipPaywall: Boolean,
    onSkip: () -> Unit,
    onSubscribe: () -> Unit
) {
    var selectedPlan by remember { mutableStateOf("yearly") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Try SayIt AI Pro Free",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onBackground
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Free trial badge
        Surface(
            color = Color(0xFF34C759),
            shape = RoundedCornerShape(20.dp)
        ) {
            Text(
                text = "7-DAY FREE TRIAL",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Features list
        val features = listOf(
            "Unlimited translations",
            "Voice conversation mode",
            "Camera text recognition",
            "Natural AI voices",
            "30+ languages",
            "No ads"
        )

        features.forEach { feature ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = feature,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onBackground
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Yearly option (highlighted with weekly price + trial)
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { selectedPlan = "yearly" }
                .then(
                    if (selectedPlan == "yearly") {
                        Modifier.border(2.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(16.dp))
                    } else {
                        Modifier
                    }
                ),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = "Yearly",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Surface(
                        color = Color(0xFF34C759),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "BEST VALUE",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "7-day free trial",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF34C759),
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "$0.58/week",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "then $29.99/year • Save 50%",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Monthly option (with weekly breakdown + trial)
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { selectedPlan = "monthly" }
                .then(
                    if (selectedPlan == "monthly") {
                        Modifier.border(2.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(16.dp))
                    } else {
                        Modifier
                    }
                ),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Monthly",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "7-day free trial",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF34C759),
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "$1.25/week",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "then $4.99/month",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Primary CTA - Start Free Trial
        Button(
            onClick = onSubscribe,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "Start 7-Day Free Trial",
                    style = MaterialTheme.typography.titleMedium
                )
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = if (selectedPlan == "yearly") "then $29.99/year" else "then $4.99/month",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        if (canSkipPaywall) {
            Spacer(modifier = Modifier.height(8.dp))

            TextButton(onClick = onSkip) {
                Text(
                    text = "Continue with free version",
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Free trial converts to paid subscription unless canceled 24 hours before trial ends. Cancel anytime.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}
