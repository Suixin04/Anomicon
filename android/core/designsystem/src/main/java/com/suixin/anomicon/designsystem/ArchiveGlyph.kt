package com.suixin.anomicon.designsystem

import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource

@Composable
fun ArchiveGlyph(name: String, modifier: Modifier = Modifier) {
    val resource = when (name) {
        "account_box" -> R.drawable.glyph_account_box
        "account_box_filled" -> R.drawable.glyph_account_box_filled
        "arrow_back" -> R.drawable.glyph_arrow_back
        "assignment" -> R.drawable.glyph_assignment
        "auto_stories" -> R.drawable.glyph_auto_stories
        "auto_stories_filled" -> R.drawable.glyph_auto_stories_filled
        "badge" -> R.drawable.glyph_badge
        "bookmark" -> R.drawable.glyph_bookmark
        "chevron_right" -> R.drawable.glyph_chevron_right
        "collections_bookmark" -> R.drawable.glyph_collections_bookmark
        "collections_bookmark_filled" -> R.drawable.glyph_collections_bookmark_filled
        "download" -> R.drawable.glyph_download
        "explore" -> R.drawable.glyph_explore
        "explore_filled" -> R.drawable.glyph_explore_filled
        "fullscreen" -> R.drawable.glyph_fullscreen
        "fullscreen_exit" -> R.drawable.glyph_fullscreen_exit
        "history" -> R.drawable.glyph_history
        "info" -> R.drawable.glyph_info
        "lock" -> R.drawable.glyph_lock
        "menu_book" -> R.drawable.glyph_menu_book
        "pause" -> R.drawable.glyph_pause
        "play_arrow" -> R.drawable.glyph_play_arrow
        "radio_button_checked" -> R.drawable.glyph_radio_button_checked
        "radio_button_unchecked" -> R.drawable.glyph_radio_button_unchecked
        "restart_alt" -> R.drawable.glyph_restart_alt
        "schedule" -> R.drawable.glyph_schedule
        "search" -> R.drawable.glyph_search
        "settings" -> R.drawable.glyph_settings
        "shield" -> R.drawable.glyph_shield
        "shield_filled" -> R.drawable.glyph_shield_filled
        "star" -> R.drawable.glyph_star
        "star_outline" -> R.drawable.glyph_star_outline
        "toc" -> R.drawable.glyph_toc
        "verified" -> R.drawable.glyph_verified
        "view_in_ar" -> R.drawable.glyph_view_in_ar
        "visibility" -> R.drawable.glyph_visibility
        "web" -> R.drawable.glyph_web
        else -> error("Unknown Material icon: $name")
    }
    Icon(painterResource(resource), contentDescription = null, modifier = modifier)
}
