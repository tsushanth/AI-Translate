package com.kreativekoala.sayitai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.kreativekoala.sayitai.data.repository.SettingsRepository
import com.kreativekoala.sayitai.ui.navigation.BottomNavItem
import com.kreativekoala.sayitai.ui.navigation.Screen
import com.kreativekoala.sayitai.ui.screens.camera.CameraTranslateScreen
import com.kreativekoala.sayitai.ui.screens.history.HistoryScreen
import com.kreativekoala.sayitai.ui.screens.onboarding.OnboardingScreen
import com.kreativekoala.sayitai.ui.screens.phrasebook.PhrasebookScreen
import com.kreativekoala.sayitai.ui.screens.settings.SettingsScreen
import com.kreativekoala.sayitai.ui.screens.text.TextTranslateScreen
import com.kreativekoala.sayitai.ui.screens.voice.VoiceConversationScreen
import com.kreativekoala.sayitai.ui.theme.AppTheme
import com.kreativekoala.sayitai.ui.theme.SayItAITheme
import com.kreativekoala.sayitai.util.DeviceCapabilityChecker
import com.kreativekoala.sayitai.util.OfflineModelManager
import com.kreativekoala.sayitai.util.TTSManager
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject
    lateinit var settingsRepository: SettingsRepository

    @Inject
    lateinit var deviceCapabilityChecker: DeviceCapabilityChecker

    @Inject
    lateinit var offlineModelManager: OfflineModelManager

    @Inject
    lateinit var ttsManager: TTSManager

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen before super.onCreate
        installSplashScreen()

        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Check if onboarding was seen
        val hasSeenOnboarding = runBlocking {
            settingsRepository.hasSeenOnboarding.first()
        }

        setContent {
            val appTheme by settingsRepository.appTheme.collectAsState(initial = AppTheme.DARK)

            SayItAITheme(appTheme = appTheme) {
                MainApp(
                    startDestination = if (hasSeenOnboarding) Screen.Main.route else Screen.Onboarding.route,
                    deviceCapabilityChecker = deviceCapabilityChecker,
                    offlineModelManager = offlineModelManager,
                    ttsManager = ttsManager
                )
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        ttsManager.shutdown()
    }
}

@Composable
fun MainApp(
    startDestination: String,
    deviceCapabilityChecker: DeviceCapabilityChecker,
    offlineModelManager: OfflineModelManager,
    ttsManager: TTSManager
) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(Screen.Onboarding.route) {
            OnboardingScreen(
                onComplete = {
                    navController.navigate(Screen.Main.route) {
                        popUpTo(Screen.Onboarding.route) { inclusive = true }
                    }
                },
                deviceCapabilityChecker = deviceCapabilityChecker
            )
        }

        composable(Screen.Main.route) {
            MainScreen(
                onNavigateToHistory = {
                    navController.navigate(Screen.History.route)
                },
                onNavigateToFavorites = {
                    navController.navigate(Screen.Favorites.route)
                },
                deviceCapabilityChecker = deviceCapabilityChecker,
                offlineModelManager = offlineModelManager
            )
        }

        composable(Screen.History.route) {
            HistoryScreen(
                isFavoritesOnly = false,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Screen.Favorites.route) {
            HistoryScreen(
                isFavoritesOnly = true,
                onBack = { navController.popBackStack() }
            )
        }
    }
}

@Composable
fun MainScreen(
    onNavigateToHistory: () -> Unit,
    onNavigateToFavorites: () -> Unit,
    deviceCapabilityChecker: DeviceCapabilityChecker,
    offlineModelManager: OfflineModelManager
) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar {
                BottomNavItem.items.forEach { item ->
                    val selected = currentDestination?.hierarchy?.any {
                        it.route == item.route
                    } == true

                    NavigationBarItem(
                        icon = {
                            Icon(
                                imageVector = if (selected) item.selectedIcon else item.unselectedIcon,
                                contentDescription = item.title
                            )
                        },
                        label = { Text(item.title) },
                        selected = selected,
                        onClick = {
                            navController.navigate(item.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = BottomNavItem.Text.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(BottomNavItem.Text.route) {
                TextTranslateScreen()
            }
            composable(BottomNavItem.Voice.route) {
                VoiceConversationScreen()
            }
            composable(BottomNavItem.Camera.route) {
                CameraTranslateScreen()
            }
            composable(BottomNavItem.Phrasebook.route) {
                PhrasebookScreen()
            }
            composable(BottomNavItem.Settings.route) {
                SettingsScreen(
                    onNavigateToHistory = onNavigateToHistory,
                    onNavigateToFavorites = onNavigateToFavorites,
                    deviceCapabilityChecker = deviceCapabilityChecker,
                    offlineModelManager = offlineModelManager
                )
            }
        }
    }
}
