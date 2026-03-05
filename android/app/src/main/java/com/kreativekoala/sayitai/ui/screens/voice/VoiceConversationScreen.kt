package com.kreativekoala.sayitai.ui.screens.voice

import android.Manifest
import android.widget.Toast
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.kreativekoala.sayitai.domain.model.ConversationMessage
import com.kreativekoala.sayitai.domain.model.ConversationSide
import com.kreativekoala.sayitai.domain.model.Language
import com.kreativekoala.sayitai.ui.components.LanguagePickerSheet

@OptIn(ExperimentalMaterial3Api::class, ExperimentalPermissionsApi::class)
@Composable
fun VoiceConversationScreen(
    viewModel: VoiceConversationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val listState = rememberLazyListState()

    val micPermissionState = rememberPermissionState(Manifest.permission.RECORD_AUDIO)

    // Track which side was clicked when permission was requested
    var pendingSide by remember { mutableStateOf<ConversationSide?>(null) }

    // Auto-start listening when permission is granted after request
    LaunchedEffect(micPermissionState.status.isGranted, pendingSide) {
        if (micPermissionState.status.isGranted && pendingSide != null) {
            // Delay to ensure permission dialog is fully dismissed and system is ready
            kotlinx.coroutines.delay(300)
            val side = pendingSide
            pendingSide = null
            if (side != null) {
                viewModel.startListening(side)
            }
        }
    }

    // Auto-scroll to bottom when new message added
    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    // Show error as toast
    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            Toast.makeText(context, it, Toast.LENGTH_LONG).show()
            viewModel.dismissError()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top bar - iOS style
            TopAppBar(
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "SayIt AI",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        // PRO badge
                        Surface(
                            color = Color.White,
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = "PRO",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color.Black,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                },
                actions = {
                    // Status indicator
                    if (uiState.isListening) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(end = 8.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(Color.Red)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Listening",
                                style = MaterialTheme.typography.labelMedium,
                                color = Color.Red
                            )
                        }
                    } else if (uiState.isSpeaking) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(end = 8.dp)
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.VolumeUp,
                                contentDescription = null,
                                tint = Color.Cyan,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Speaking",
                                style = MaterialTheme.typography.labelMedium,
                                color = Color.Cyan
                            )
                        }
                    }

                    // Settings button
                    IconButton(
                        onClick = {
                            if (uiState.messages.isNotEmpty()) {
                                viewModel.clearConversation()
                            }
                        }
                    ) {
                        Icon(
                            Icons.Default.Settings,
                            contentDescription = "Settings",
                            tint = Color.White.copy(alpha = 0.7f)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                )
            )

            // Conversation messages
            if (uiState.messages.isEmpty()) {
                // Empty state
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            Icons.Default.RecordVoiceOver,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = Color.White.copy(alpha = 0.3f)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "Tap a language to start speaking",
                            style = MaterialTheme.typography.bodyLarge,
                            color = Color.White.copy(alpha = 0.5f),
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Hold down the button while speaking",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.3f),
                            textAlign = TextAlign.Center
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    state = listState,
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    contentPadding = PaddingValues(vertical = 16.dp)
                ) {
                    items(uiState.messages) { message ->
                        ConversationBubble(
                            message = message,
                            onSpeak = { viewModel.speakMessage(message) },
                            onCopy = { /* TODO */ }
                        )
                    }
                }
            }

            // Listening indicator
            if (uiState.partialSpeechResult.isNotBlank()) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = Color.Red.copy(alpha = 0.15f)
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.GraphicEq,
                            contentDescription = null,
                            tint = Color.Red,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "Listening...",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Medium,
                                color = Color.White
                            )
                            if (uiState.partialSpeechResult.isNotBlank()) {
                                Text(
                                    text = uiState.partialSpeechResult,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
            }

            // Bottom controls - iOS style with flags
            BottomControls(
                leftLanguage = uiState.leftLanguage,
                rightLanguage = uiState.rightLanguage,
                isListening = uiState.isListening,
                activeSide = uiState.activeSide,
                hasPermission = micPermissionState.status.isGranted,
                onLeftClick = {
                    if (micPermissionState.status.isGranted) {
                        if (uiState.isListening && uiState.activeSide == ConversationSide.LEFT) {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening(ConversationSide.LEFT)
                        }
                    } else {
                        pendingSide = ConversationSide.LEFT
                        micPermissionState.launchPermissionRequest()
                    }
                },
                onRightClick = {
                    if (micPermissionState.status.isGranted) {
                        if (uiState.isListening && uiState.activeSide == ConversationSide.RIGHT) {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening(ConversationSide.RIGHT)
                        }
                    } else {
                        pendingSide = ConversationSide.RIGHT
                        micPermissionState.launchPermissionRequest()
                    }
                },
                onClearClick = {
                    if (uiState.isListening) {
                        viewModel.stopListening()
                    } else {
                        viewModel.clearConversation()
                    }
                },
                onLeftLongClick = { viewModel.showLeftLanguagePicker(true) },
                onRightLongClick = { viewModel.showRightLanguagePicker(true) }
            )
        }
    }

    // Language picker sheets
    if (uiState.showLeftLanguagePicker) {
        LanguagePickerSheet(
            languages = Language.supportedLanguages,
            selectedLanguage = uiState.leftLanguage,
            onLanguageSelected = { viewModel.setLeftLanguage(it) },
            onDismiss = { viewModel.showLeftLanguagePicker(false) },
            title = "Left Speaker Language"
        )
    }

    if (uiState.showRightLanguagePicker) {
        LanguagePickerSheet(
            languages = Language.supportedLanguages,
            selectedLanguage = uiState.rightLanguage,
            onLanguageSelected = { viewModel.setRightLanguage(it) },
            onDismiss = { viewModel.showRightLanguagePicker(false) },
            title = "Right Speaker Language"
        )
    }
}

@Composable
private fun BottomControls(
    leftLanguage: Language,
    rightLanguage: Language,
    isListening: Boolean,
    activeSide: ConversationSide?,
    hasPermission: Boolean,
    onLeftClick: () -> Unit,
    onRightClick: () -> Unit,
    onClearClick: () -> Unit,
    onLeftLongClick: () -> Unit,
    onRightLongClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.Black)
            .padding(vertical = 24.dp, horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Left language button with flag
        LanguageRecordButton(
            language = leftLanguage,
            isRecording = isListening && activeSide == ConversationSide.LEFT,
            isDisabled = isListening && activeSide != ConversationSide.LEFT,
            onClick = onLeftClick,
            onLongClick = onLeftLongClick
        )

        // Center clear/stop button
        Surface(
            modifier = Modifier
                .size(56.dp)
                .clip(CircleShape)
                .clickable(onClick = onClearClick),
            color = Color.Gray.copy(alpha = 0.3f),
            shape = CircleShape
        ) {
            Box(
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = if (isListening) "Stop" else "Clear",
                    modifier = Modifier.size(24.dp),
                    tint = Color.White
                )
            }
        }

        // Right language button with flag
        LanguageRecordButton(
            language = rightLanguage,
            isRecording = isListening && activeSide == ConversationSide.RIGHT,
            isDisabled = isListening && activeSide != ConversationSide.RIGHT,
            onClick = onRightClick,
            onLongClick = onRightLongClick
        )
    }
}

@Composable
private fun LanguageRecordButton(
    language: Language,
    isRecording: Boolean,
    isDisabled: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit
) {
    val scale by animateFloatAsState(
        targetValue = if (isRecording) 1.15f else 1f,
        animationSpec = tween(800),
        label = "pulse"
    )

    Box(
        contentAlignment = Alignment.Center
    ) {
        // Pulsing background when recording
        if (isRecording) {
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .scale(scale)
                    .clip(CircleShape)
                    .background(Color.Red.copy(alpha = 0.2f))
            )
        }

        // Main button
        Surface(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .clickable(
                    enabled = !isDisabled,
                    onClick = onClick
                ),
            color = if (isRecording) Color.Red else Color.Transparent,
            shape = CircleShape,
            border = if (!isRecording) {
                ButtonDefaults.outlinedButtonBorder.copy(
                    width = 3.dp,
                    brush = Brush.linearGradient(
                        colors = listOf(Color.White.copy(alpha = 0.3f), Color.White.copy(alpha = 0.3f))
                    )
                )
            } else null
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (isDisabled) Modifier.background(Color.Black.copy(alpha = 0.5f))
                        else Modifier
                    )
            ) {
                if (isRecording) {
                    // Stop icon (square) when recording
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(Color.White)
                    )
                } else {
                    // Flag emoji when not recording
                    Text(
                        text = language.flagEmoji,
                        fontSize = 40.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun ConversationBubble(
    message: ConversationMessage,
    onSpeak: () -> Unit,
    onCopy: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.Gray.copy(alpha = 0.15f)
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // Original text
            Text(
                text = message.originalText,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Medium,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Translation
            Text(
                text = message.translatedText,
                style = MaterialTheme.typography.titleMedium,
                color = Color.Cyan
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Divider
            HorizontalDivider(
                color = Color.Gray.copy(alpha = 0.3f),
                thickness = 1.dp
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row {
                    // Favorite button
                    IconButton(
                        onClick = { /* TODO */ },
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            Icons.Outlined.FavoriteBorder,
                            contentDescription = "Favorite",
                            modifier = Modifier.size(20.dp),
                            tint = Color.Gray
                        )
                    }

                    // Copy button
                    IconButton(
                        onClick = onCopy,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            Icons.Outlined.ContentCopy,
                            contentDescription = "Copy",
                            modifier = Modifier.size(20.dp),
                            tint = Color.Gray
                        )
                    }
                }

                // Speaker button
                IconButton(
                    onClick = onSpeak,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.VolumeUp,
                        contentDescription = "Speak",
                        modifier = Modifier.size(20.dp),
                        tint = Color.Gray
                    )
                }
            }
        }
    }
}
