package com.kreativekoala.sayitai.ui.screens.text

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.kreativekoala.sayitai.domain.model.Language
import com.kreativekoala.sayitai.ui.components.LanguagePickerSheet
import com.kreativekoala.sayitai.ui.components.OfflineBanner
import com.kreativekoala.sayitai.ui.components.OfflineIndicator

@OptIn(ExperimentalMaterial3Api::class, ExperimentalPermissionsApi::class)
@Composable
fun TextTranslateScreen(
    viewModel: TextTranslateViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    val micPermissionState = rememberPermissionState(Manifest.permission.RECORD_AUDIO)

    // Track if we're waiting for permission to start listening
    var pendingMicAction by remember { mutableStateOf(false) }

    // Auto-start listening when permission is granted after a request
    LaunchedEffect(micPermissionState.status.isGranted, pendingMicAction) {
        if (micPermissionState.status.isGranted && pendingMicAction) {
            // Delay to ensure permission dialog is fully dismissed and system is ready
            kotlinx.coroutines.delay(300)
            if (pendingMicAction) {
                pendingMicAction = false
                viewModel.startListening()
            }
        }
    }

    // Clipboard manager
    val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    // Vibrator for haptic feedback
    val vibrator = remember {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    fun hapticFeedback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(50)
        }
    }

    fun copyToClipboard(text: String) {
        val clip = ClipData.newPlainText("Translation", text)
        clipboardManager.setPrimaryClip(clip)
        hapticFeedback()
        Toast.makeText(context, "Copied to clipboard", Toast.LENGTH_SHORT).show()
    }

    fun pasteFromClipboard(): String? {
        return clipboardManager.primaryClip?.getItemAt(0)?.text?.toString()
    }

    // Show error as toast
    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_LONG).show()
            viewModel.dismissError()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Offline banner at top
        AnimatedVisibility(
            visible = !uiState.isOnline,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            OfflineBanner(modifier = Modifier.fillMaxWidth())
        }

        // Top bar with app name
        TopAppBar(
            title = {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "SayIt AI",
                        style = MaterialTheme.typography.headlineMedium
                    )
                    if (!uiState.isOnline) {
                        Spacer(modifier = Modifier.width(8.dp))
                        OfflineIndicator(showText = false)
                    }
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
        ) {
            // Language selector row
            LanguageSelectorRow(
                sourceLanguage = uiState.sourceLanguage,
                targetLanguage = uiState.targetLanguage,
                detectedLanguage = uiState.detectedLanguage,
                onSourceClick = { viewModel.showSourceLanguagePicker(true) },
                onTargetClick = { viewModel.showTargetLanguagePicker(true) },
                onSwapClick = {
                    hapticFeedback()
                    viewModel.swapLanguages()
                }
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Source text input card
            SourceTextCard(
                text = uiState.sourceText,
                partialResult = uiState.partialSpeechResult,
                isListening = uiState.isListening,
                isSpeaking = uiState.isSourceSpeaking,
                onTextChange = viewModel::updateSourceText,
                onMicClick = {
                    if (micPermissionState.status.isGranted) {
                        if (uiState.isListening) {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening()
                        }
                    } else {
                        pendingMicAction = true
                        micPermissionState.launchPermissionRequest()
                    }
                },
                onSpeakClick = { viewModel.speakSource() },
                onCopyClick = { copyToClipboard(uiState.sourceText) },
                onPasteClick = {
                    pasteFromClipboard()?.let { viewModel.updateSourceText(it) }
                },
                onClearClick = { viewModel.clearText() }
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Translate button
            Button(
                onClick = { viewModel.translate() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                enabled = uiState.sourceText.isNotBlank() && !uiState.isTranslating,
                shape = RoundedCornerShape(12.dp)
            ) {
                if (uiState.isTranslating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Translating...")
                } else {
                    Icon(Icons.Default.Translate, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Translate")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Translation result card
            AnimatedVisibility(
                visible = uiState.translatedText.isNotBlank(),
                enter = fadeIn(),
                exit = fadeOut()
            ) {
                TranslationResultCard(
                    text = uiState.translatedText,
                    isSpeaking = uiState.isTargetSpeaking,
                    isOffline = uiState.isOfflineTranslation,
                    onSpeakClick = { viewModel.speakTarget() },
                    onCopyClick = { copyToClipboard(uiState.translatedText) }
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }

    // Language picker sheets
    if (uiState.showSourceLanguagePicker) {
        LanguagePickerSheet(
            languages = Language.allLanguages,
            selectedLanguage = uiState.sourceLanguage,
            onLanguageSelected = { viewModel.setSourceLanguage(it) },
            onDismiss = { viewModel.showSourceLanguagePicker(false) },
            title = "Source Language"
        )
    }

    if (uiState.showTargetLanguagePicker) {
        LanguagePickerSheet(
            languages = Language.supportedLanguages,
            selectedLanguage = uiState.targetLanguage,
            onLanguageSelected = { viewModel.setTargetLanguage(it) },
            onDismiss = { viewModel.showTargetLanguagePicker(false) },
            title = "Target Language"
        )
    }
}

@Composable
private fun LanguageSelectorRow(
    sourceLanguage: Language,
    targetLanguage: Language,
    detectedLanguage: Language?,
    onSourceClick: () -> Unit,
    onTargetClick: () -> Unit,
    onSwapClick: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Source language
        LanguageChip(
            language = detectedLanguage ?: sourceLanguage,
            isDetected = detectedLanguage != null,
            onClick = onSourceClick,
            modifier = Modifier.weight(1f)
        )

        // Swap button
        IconButton(
            onClick = onSwapClick,
            modifier = Modifier
                .padding(horizontal = 8.dp)
                .size(40.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Icon(
                Icons.Default.SwapHoriz,
                contentDescription = "Swap languages",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Target language
        LanguageChip(
            language = targetLanguage,
            isDetected = false,
            onClick = onTargetClick,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun LanguageChip(
    language: Language,
    isDetected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = language.flagEmoji,
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column {
                Text(
                    text = language.name,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (isDetected) {
                    Text(
                        text = "Detected",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
            Spacer(modifier = Modifier.width(4.dp))
            Icon(
                Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun SourceTextCard(
    text: String,
    partialResult: String,
    isListening: Boolean,
    isSpeaking: Boolean,
    onTextChange: (String) -> Unit,
    onMicClick: () -> Unit,
    onSpeakClick: () -> Unit,
    onCopyClick: () -> Unit,
    onPasteClick: () -> Unit,
    onClearClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // Text input area
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 120.dp, max = 200.dp)
            ) {
                val displayText = if (isListening && partialResult.isNotEmpty()) {
                    partialResult
                } else {
                    text
                }

                BasicTextField(
                    value = displayText,
                    onValueChange = onTextChange,
                    modifier = Modifier.fillMaxSize(),
                    textStyle = MaterialTheme.typography.bodyLarge.copy(
                        color = MaterialTheme.colorScheme.onSurface
                    ),
                    cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                    enabled = !isListening,
                    decorationBox = { innerTextField ->
                        Box {
                            if (displayText.isEmpty()) {
                                Text(
                                    text = "Enter text to translate",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            innerTextField()
                        }
                    }
                )

                // Listening indicator
                if (isListening) {
                    Row(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(top = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Listening...",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }

            // Character count
            Text(
                text = "${text.length}/5000",
                style = MaterialTheme.typography.labelSmall,
                color = if (text.length > 5000) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.align(Alignment.End)
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row {
                    // Mic button
                    IconButton(onClick = onMicClick) {
                        Icon(
                            if (isListening) Icons.Default.Stop else Icons.Default.Mic,
                            contentDescription = "Voice input",
                            tint = if (isListening) MaterialTheme.colorScheme.error
                            else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // Speak button
                    IconButton(
                        onClick = onSpeakClick,
                        enabled = text.isNotBlank() && !isSpeaking
                    ) {
                        Icon(
                            if (isSpeaking) Icons.Default.VolumeUp else Icons.Outlined.VolumeUp,
                            contentDescription = "Speak",
                            tint = if (isSpeaking) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // Copy button
                    IconButton(
                        onClick = onCopyClick,
                        enabled = text.isNotBlank()
                    ) {
                        Icon(
                            Icons.Outlined.ContentCopy,
                            contentDescription = "Copy",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // Paste button
                    IconButton(onClick = onPasteClick) {
                        Icon(
                            Icons.Outlined.ContentPaste,
                            contentDescription = "Paste",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Clear button
                if (text.isNotBlank()) {
                    IconButton(onClick = onClearClick) {
                        Icon(
                            Icons.Default.Clear,
                            contentDescription = "Clear",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TranslationResultCard(
    text: String,
    isSpeaking: Boolean,
    isOffline: Boolean = false,
    onSpeakClick: () -> Unit,
    onCopyClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Translation",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary
                )
                if (isOffline) {
                    OfflineIndicator()
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = text,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface
            )

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                // Speak button
                IconButton(
                    onClick = onSpeakClick,
                    enabled = !isSpeaking
                ) {
                    Icon(
                        if (isSpeaking) Icons.Default.VolumeUp else Icons.Outlined.VolumeUp,
                        contentDescription = "Speak translation",
                        tint = if (isSpeaking) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                // Copy button
                IconButton(onClick = onCopyClick) {
                    Icon(
                        Icons.Outlined.ContentCopy,
                        contentDescription = "Copy translation",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}
