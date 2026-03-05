package com.kreativekoala.sayitai.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.ui.graphics.vector.ImageVector

sealed class Screen(val route: String) {
    data object Onboarding : Screen("onboarding")
    data object Main : Screen("main")
    data object History : Screen("history")
    data object Favorites : Screen("favorites")
}

sealed class BottomNavItem(
    val route: String,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    data object Text : BottomNavItem(
        route = "text",
        title = "Text",
        selectedIcon = Icons.Filled.Translate,
        unselectedIcon = Icons.Outlined.Translate
    )

    data object Voice : BottomNavItem(
        route = "voice",
        title = "Voice",
        selectedIcon = Icons.Filled.Mic,
        unselectedIcon = Icons.Outlined.Mic
    )

    data object Camera : BottomNavItem(
        route = "camera",
        title = "Camera",
        selectedIcon = Icons.Filled.CameraAlt,
        unselectedIcon = Icons.Outlined.CameraAlt
    )

    data object Phrasebook : BottomNavItem(
        route = "phrasebook",
        title = "Phrases",
        selectedIcon = Icons.Filled.MenuBook,
        unselectedIcon = Icons.Outlined.MenuBook
    )

    data object Settings : BottomNavItem(
        route = "settings",
        title = "More",
        selectedIcon = Icons.Filled.MoreHoriz,
        unselectedIcon = Icons.Outlined.MoreHoriz
    )

    companion object {
        val items = listOf(Text, Voice, Camera, Phrasebook, Settings)
    }
}
