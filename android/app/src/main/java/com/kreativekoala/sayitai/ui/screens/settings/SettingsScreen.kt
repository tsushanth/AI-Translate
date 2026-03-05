package com.kreativekoala.sayitai.ui.screens.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.kreativekoala.sayitai.BuildConfig
import com.kreativekoala.sayitai.data.repository.TranslationProvider
import com.kreativekoala.sayitai.ui.theme.AppTheme
import com.kreativekoala.sayitai.util.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateToHistory: () -> Unit,
    onNavigateToFavorites: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
    deviceCapabilityChecker: DeviceCapabilityChecker,
    offlineModelManager: OfflineModelManager
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    var showClearHistoryDialog by remember { mutableStateOf(false) }
    var showOfflineModelsSheet by remember { mutableStateOf(false) }

    // Collect offline model manager states
    val downloadedWhisperModel by offlineModelManager.downloadedWhisperModel.collectAsState()
    val isNLLBDownloaded by offlineModelManager.isNLLBDownloaded.collectAsState()
    val downloadStatus by offlineModelManager.downloadStatus.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        TopAppBar(
            title = {
                Text(
                    "Settings",
                    style = MaterialTheme.typography.headlineMedium
                )
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // History Section
            item {
                SettingsSection(title = null) {
                    SettingsItem(
                        icon = Icons.Outlined.History,
                        iconTint = MaterialTheme.colorScheme.primary,
                        title = "Translation History",
                        subtitle = if (uiState.historyCount > 0) "${uiState.historyCount} entries" else null,
                        onClick = onNavigateToHistory
                    )
                    SettingsItem(
                        icon = Icons.Default.Star,
                        iconTint = Color(0xFFFFD700),
                        title = "Favorites",
                        subtitle = if (uiState.favoritesCount > 0) "${uiState.favoritesCount} entries" else null,
                        onClick = onNavigateToFavorites
                    )
                }
            }

            // Offline Models Section (only for supported devices)
            if (deviceCapabilityChecker.supportsOfflineMode) {
                item {
                    SettingsSection(title = "Offline Mode") {
                        SettingsItem(
                            icon = Icons.Outlined.CloudDownload,
                            iconTint = Color(0xFF34C759),
                            title = "Offline Models",
                            subtitle = buildOfflineStatusSubtitle(downloadedWhisperModel, isNLLBDownloaded),
                            onClick = { showOfflineModelsSheet = true }
                        )

                        // Storage info
                        if (downloadedWhisperModel != null || isNLLBDownloaded) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Outlined.Storage,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    text = "Storage used: ${offlineModelManager.totalDownloadedSizeFormatted()}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            // Appearance Section
            item {
                SettingsSection(title = "Appearance") {
                    SettingsDropdownItem(
                        icon = Icons.Outlined.Palette,
                        title = "Theme",
                        selectedValue = when (uiState.appTheme) {
                            AppTheme.SYSTEM -> "System"
                            AppTheme.LIGHT -> "Light"
                            AppTheme.DARK -> "Dark"
                        },
                        options = listOf("System", "Light", "Dark"),
                        onOptionSelected = { option ->
                            val theme = when (option) {
                                "System" -> AppTheme.SYSTEM
                                "Light" -> AppTheme.LIGHT
                                else -> AppTheme.DARK
                            }
                            viewModel.setAppTheme(theme)
                        }
                    )
                }
            }

            // Translation Engine Section
            item {
                SettingsSection(title = "Translation Engine") {
                    TranslationProvider.entries.forEach { provider ->
                        SettingsRadioItem(
                            title = provider.displayName,
                            subtitle = provider.description,
                            isSelected = uiState.translationProvider == provider,
                            onClick = { viewModel.setTranslationProvider(provider) }
                        )
                    }
                }
            }

            // Preferences Section
            item {
                SettingsSection(title = "Preferences") {
                    SettingsSwitchItem(
                        icon = Icons.Outlined.Language,
                        title = "Auto-detect Language",
                        isChecked = uiState.autoDetectLanguage,
                        onCheckedChange = { viewModel.setAutoDetectLanguage(it) }
                    )
                    SettingsSwitchItem(
                        icon = Icons.Outlined.Vibration,
                        title = "Haptic Feedback",
                        isChecked = uiState.hapticFeedback,
                        onCheckedChange = { viewModel.setHapticFeedback(it) }
                    )
                }
            }

            // Data Section
            item {
                SettingsSection(title = "Data") {
                    SettingsItem(
                        icon = Icons.Outlined.Delete,
                        iconTint = MaterialTheme.colorScheme.error,
                        title = "Clear All History",
                        titleColor = MaterialTheme.colorScheme.error,
                        onClick = { showClearHistoryDialog = true },
                        enabled = uiState.historyCount > 0
                    )
                }
            }

            // About Section
            item {
                SettingsSection(title = "About") {
                    SettingsItem(
                        icon = Icons.Outlined.Info,
                        title = "Version",
                        subtitle = BuildConfig.VERSION_NAME
                    )

                    // Device capability info
                    SettingsItem(
                        icon = Icons.Outlined.PhoneAndroid,
                        title = "Device",
                        subtitle = "${deviceCapabilityChecker.deviceName} • ${deviceCapabilityChecker.offlineCapability.displayName}"
                    )

                    SettingsItem(
                        icon = Icons.Outlined.PrivacyTip,
                        title = "Privacy Policy",
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://kreativekoala.llc/privacy"))
                            context.startActivity(intent)
                        }
                    )
                    SettingsItem(
                        icon = Icons.Outlined.Description,
                        title = "Terms of Service",
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://kreativekoala.llc/terms"))
                            context.startActivity(intent)
                        }
                    )
                    SettingsItem(
                        icon = Icons.Outlined.Email,
                        title = "Contact Us",
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://kreativekoala.llc/contact"))
                            context.startActivity(intent)
                        }
                    )
                }
            }
        }
    }

    // Clear history confirmation dialog
    if (showClearHistoryDialog) {
        AlertDialog(
            onDismissRequest = { showClearHistoryDialog = false },
            title = { Text("Clear All History") },
            text = { Text("This will permanently delete all translation history and favorites. This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.clearAllHistory()
                        showClearHistoryDialog = false
                    }
                ) {
                    Text("Clear All", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearHistoryDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Offline Models Bottom Sheet
    if (showOfflineModelsSheet) {
        ModalBottomSheet(
            onDismissRequest = { showOfflineModelsSheet = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            OfflineModelsSheet(
                deviceCapabilityChecker = deviceCapabilityChecker,
                offlineModelManager = offlineModelManager,
                onDismiss = { showOfflineModelsSheet = false }
            )
        }
    }
}

@Composable
private fun buildOfflineStatusSubtitle(
    downloadedWhisperModel: WhisperModelSize?,
    isNLLBDownloaded: Boolean
): String {
    val parts = mutableListOf<String>()

    downloadedWhisperModel?.let {
        parts.add("Whisper ${it.displayName}")
    }

    if (isNLLBDownloaded) {
        parts.add("NLLB")
    }

    return if (parts.isEmpty()) {
        "No models downloaded"
    } else {
        parts.joinToString(" • ")
    }
}

@Composable
private fun OfflineModelsSheet(
    deviceCapabilityChecker: DeviceCapabilityChecker,
    offlineModelManager: OfflineModelManager,
    onDismiss: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()
    val offlineCapability = deviceCapabilityChecker.offlineCapability
    val supportedModels = offlineCapability.supportedWhisperModels
    val recommendedModel = offlineCapability.recommendedWhisperModel

    val downloadedWhisperModel by offlineModelManager.downloadedWhisperModel.collectAsState()
    val isNLLBDownloaded by offlineModelManager.isNLLBDownloaded.collectAsState()
    val downloadStatus by offlineModelManager.downloadStatus.collectAsState()
    val currentlyDownloading by offlineModelManager.currentlyDownloading.collectAsState()

    var showDeleteConfirmation by remember { mutableStateOf<OfflineModelType?>(null) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(bottom = 32.dp)
    ) {
        Text(
            text = "Offline Models",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Download models to use the app without internet",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Status Section
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Status",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(12.dp))

                // Speech Recognition status
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        if (offlineModelManager.canRecognizeSpeechOffline()) Icons.Default.CheckCircle else Icons.Default.Cancel,
                        contentDescription = null,
                        tint = if (offlineModelManager.canRecognizeSpeechOffline()) Color(0xFF34C759) else Color(0xFFFF3B30),
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Speech Recognition", style = MaterialTheme.typography.bodyMedium)
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        if (offlineModelManager.canRecognizeSpeechOffline()) "Ready" else "Not Available",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Translation status
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        if (isNLLBDownloaded) Icons.Default.CheckCircle else Icons.Default.Cancel,
                        contentDescription = null,
                        tint = if (isNLLBDownloaded) Color(0xFF34C759) else Color(0xFFFF3B30),
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Full Translation", style = MaterialTheme.typography.bodyMedium)
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        if (isNLLBDownloaded) "Ready" else "English Only",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                if (downloadedWhisperModel != null || isNLLBDownloaded) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.Storage,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Storage Used", style = MaterialTheme.typography.bodyMedium)
                        Spacer(modifier = Modifier.weight(1f))
                        Text(
                            offlineModelManager.totalDownloadedSizeFormatted(),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Whisper Models Section
        Text(
            text = "Speech Recognition Models",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(8.dp))

        supportedModels.forEach { model ->
            val modelType = when (model) {
                WhisperModelSize.TINY -> OfflineModelType.WHISPER_TINY
                WhisperModelSize.SMALL -> OfflineModelType.WHISPER_SMALL
                WhisperModelSize.MEDIUM -> OfflineModelType.WHISPER_MEDIUM
            }
            val isDownloaded = offlineModelManager.isModelDownloaded(modelType)
            val isRecommended = model == recommendedModel
            val isCurrentlyDownloading = currentlyDownloading == modelType
            val performanceEstimate = deviceCapabilityChecker.getPerformanceEstimate(model)

            ModelRow(
                title = model.displayName,
                subtitle = "${model.downloadSize} • ${model.accuracyDescription}",
                performanceEstimate = performanceEstimate,
                isDownloaded = isDownloaded,
                isRecommended = isRecommended,
                isDownloading = isCurrentlyDownloading,
                onDownload = {
                    coroutineScope.launch {
                        try {
                            offlineModelManager.downloadModel(modelType)
                        } catch (e: Exception) {
                            // Handle error
                        }
                    }
                },
                onDelete = { showDeleteConfirmation = modelType }
            )

            Spacer(modifier = Modifier.height(8.dp))
        }

        Spacer(modifier = Modifier.height(16.dp))

        // NLLB Model Section
        Text(
            text = "Translation Model",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(8.dp))

        ModelRow(
            title = "NLLB Translation",
            subtitle = "~600 MB • Enables 30-language translation",
            performanceEstimate = null,
            isDownloaded = isNLLBDownloaded,
            isRecommended = false,
            isDownloading = currentlyDownloading == OfflineModelType.NLLB,
            onDownload = {
                coroutineScope.launch {
                    try {
                        offlineModelManager.downloadModel(OfflineModelType.NLLB)
                    } catch (e: Exception) {
                        // Handle error
                    }
                }
            },
            onDelete = { showDeleteConfirmation = OfflineModelType.NLLB }
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "NLLB enables translation between all 30 languages. Without it, you can only translate speech to English.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }

    // Delete confirmation dialog
    showDeleteConfirmation?.let { modelType ->
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = null },
            title = { Text("Delete ${modelType.displayName}?") },
            text = { Text("This will remove the model from your device. You can download it again later.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        offlineModelManager.deleteModel(modelType)
                        showDeleteConfirmation = null
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun ModelRow(
    title: String,
    subtitle: String,
    performanceEstimate: PerformanceEstimate?,
    isDownloaded: Boolean,
    isRecommended: Boolean,
    isDownloading: Boolean,
    onDownload: () -> Unit,
    onDelete: () -> Unit
) {
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
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )

                    if (isRecommended) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Surface(
                            color = Color(0xFF34C759),
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = "REC",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }

                    if (isDownloaded) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = "Downloaded",
                            tint = Color(0xFF34C759),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                performanceEstimate?.let { estimate ->
                    Spacer(modifier = Modifier.height(4.dp))
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
                            text = estimate.displayText,
                            style = MaterialTheme.typography.labelSmall,
                            color = when (estimate.statusColor) {
                                "green" -> Color(0xFF34C759)
                                "orange" -> Color(0xFFFF9500)
                                "red" -> Color(0xFFFF3B30)
                                else -> MaterialTheme.colorScheme.onSurfaceVariant
                            }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.width(12.dp))

            if (isDownloading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    strokeWidth = 2.dp
                )
            } else if (isDownloaded) {
                TextButton(
                    onClick = onDelete,
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Delete")
                }
            } else {
                Button(
                    onClick = onDownload,
                    modifier = Modifier.height(36.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp)
                ) {
                    Text("Download", style = MaterialTheme.typography.labelMedium)
                }
            }
        }
    }
}

@Composable
private fun SettingsSection(
    title: String?,
    content: @Composable ColumnScope.() -> Unit
) {
    Column {
        title?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            )
        ) {
            Column(content = content)
        }
    }
}

@Composable
private fun SettingsItem(
    icon: ImageVector? = null,
    iconTint: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    title: String,
    titleColor: Color = MaterialTheme.colorScheme.onSurface,
    subtitle: String? = null,
    onClick: (() -> Unit)? = null,
    enabled: Boolean = true
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (onClick != null && enabled) {
                    Modifier.clickable(onClick = onClick)
                } else {
                    Modifier
                }
            ),
        color = Color.Transparent
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            icon?.let {
                Icon(
                    it,
                    contentDescription = null,
                    tint = if (enabled) iconTint else iconTint.copy(alpha = 0.5f),
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(16.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge,
                    color = if (enabled) titleColor else titleColor.copy(alpha = 0.5f)
                )
                subtitle?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(
                            alpha = if (enabled) 1f else 0.5f
                        )
                    )
                }
            }
            if (onClick != null) {
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(
                        alpha = if (enabled) 1f else 0.5f
                    )
                )
            }
        }
    }
}

@Composable
private fun SettingsSwitchItem(
    icon: ImageVector? = null,
    title: String,
    isChecked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.Transparent
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            icon?.let {
                Icon(
                    it,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(16.dp))
            }
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f)
            )
            Switch(
                checked = isChecked,
                onCheckedChange = onCheckedChange
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsDropdownItem(
    icon: ImageVector? = null,
    title: String,
    selectedValue: String,
    options: List<String>,
    onOptionSelected: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { expanded = true },
        color = Color.Transparent
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            icon?.let {
                Icon(
                    it,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(16.dp))
            }
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f)
            )
            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { expanded = it }
            ) {
                Row(
                    modifier = Modifier.menuAnchor(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = selectedValue,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Icon(
                        Icons.Default.KeyboardArrowDown,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    options.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            onClick = {
                                onOptionSelected(option)
                                expanded = false
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsRadioItem(
    title: String,
    subtitle: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        color = Color.Transparent
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            RadioButton(
                selected = isSelected,
                onClick = onClick
            )
        }
    }
}
