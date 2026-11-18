# PHASE63.19 — Bottom Navigation Selection and Global Press Feedback (2026-11-15)

## Goal

Polish RAVEN23's two-tier bottom navigation and give interactive controls a consistent, small press response without replacing their existing tap handlers, ink effects, haptics, accessibility semantics, scroll behavior or TV focus behavior.

## Bottom navigation changes

- The centre action that opens the secondary dock now includes a one-space caption (`' '`). It reserves the same label row as the other primary destinations but renders no visible label.
- The centre icon's existing 30 logical-pixel size (and the existing collapsed-dock value) was not reduced or otherwise changed to make room for the blank caption.
- The centre action and primary navigation destinations apply the shared press response to the icon and caption together.
- When Movies, Series or Anime is selected from the secondary dock, Home remains selected in the primary dock and the chosen secondary destination remains selected in the still-visible secondary dock.
- Selecting a primary destination such as Home, New & Hot, Discover or Mine closes the secondary dock as before. The centre action can still close/reopen the secondary dock.

## Shared interaction feedback

- Added `lib/design/app_press_feedback.dart` as the common touch-feedback wrapper.
- Default press response: scale `0.985`, 100 ms, `Curves.easeOutCubic`.
- The wrapper observes raw pointer down/move/up/cancel events through `Listener`; it does not compete with the child control's GestureDetector/InkWell recognizer or replace its callbacks.
- A pointer movement over 10 logical pixels releases the pressed visual state so a scroll/drag does not keep a control visually depressed.
- The response respects Android/Flutter reduced-motion settings through `MediaQuery.disableAnimationsOf`.
- Applied to standard Material buttons, IconButtons, InkWells, callback-backed ListTiles and switch/checkbox/radio tiles, PopupMenuItem/DropdownMenuItem rows, callback-enabled Choice/Filter/Input/Action chips, and relevant custom pointer controls throughout the application.
- Existing poster-card and Plus-card press animations were unified with the shared scale. Playback controls and TV subtitle timing buttons retain their existing pressed-colour and focus behavior while receiving the shared light scale response.
- Swipe surfaces, manga-reader page gestures, player-sheet drag handles, chart scrubbing and decorative/ad-background tap regions were not given a button press effect because they are gesture surfaces rather than discrete controls.

## Tests and CI

- Updated `test/mobile/mobile_nav_bar_test.dart` to check the blank menu caption, preserved centre icon size, simultaneous Home + secondary selection for Movies/Series/Anime, and that the shared scale response does not steal an IconButton tap.
- The existing focused Flutter test gate already includes `test/mobile/mobile_nav_bar_test.dart`; no test suite was added or removed.
- Increased the scoped Dart formatter inventory from 79 to 146 unique targets to include every changed Dart file and the new press-feedback widget.
- Updated the CI report text to describe the broader formatter scope and navigation/press-feedback assertions.

## Validation boundary

- Static source delimiter scan found no new unbalanced delimiters in the edited Dart files; the only unmatched-brace warning is the same pre-existing baseline finding in `lib/controllers/wellness_database_controller.dart:377`.
- All `AppPressFeedback` usages have a matching import; formatter targets are unique and exist.
- The CI YAML and formatter script receive structural checks before packaging.
- Dart/Flutter are not installed in the editing environment. `dart format`, `flutter analyze`, Flutter tests, Gradle/Kotlin compilation, APK build and visual/device testing have **not** been run here. The GitHub Actions run must confirm formatting, Analyze, focused tests and APK build; a device check should verify the visual press amount and the two simultaneous selection highlights.

## Changed Dart files

- `lib/design/app_press_feedback.dart`
- `lib/manga/mihon/mihon_source_browser_screen.dart`
- `lib/manga/ui/manga_reader_screen.dart`
- `lib/manga/ui/manga_work_screen.dart`
- `lib/mobile/app/mobile_nav_bar.dart`
- `lib/mobile/app/mobile_shell.dart`
- `lib/mobile/playlists.dart`
- `lib/mobile/screens/credits_screen.dart`
- `lib/mobile/screens/discover_screen.dart`
- `lib/mobile/screens/episode_screen.dart`
- `lib/mobile/screens/flix_ai_screen.dart`
- `lib/mobile/screens/manga_screen.dart`
- `lib/mobile/screens/my_raven23_screen.dart`
- `lib/mobile/screens/person_screen.dart`
- `lib/mobile/screens/playlist_import_screen.dart`
- `lib/mobile/screens/playlist_screen.dart`
- `lib/mobile/screens/playlists_screen.dart`
- `lib/mobile/screens/plus_payment_screen.dart`
- `lib/mobile/screens/plus_screen.dart`
- `lib/mobile/screens/search_screen.dart`
- `lib/mobile/screens/season_screen.dart`
- `lib/mobile/screens/shared_playlist_screen.dart`
- `lib/mobile/screens/title_details_screen.dart`
- `lib/mobile/widgets/account_form.dart`
- `lib/mobile/widgets/continue_sheet.dart`
- `lib/mobile/widgets/details_header.dart`
- `lib/mobile/widgets/details_parts.dart`
- `lib/mobile/widgets/device_limit_sheet.dart`
- `lib/mobile/widgets/episode_row.dart`
- `lib/mobile/widgets/episodes_section.dart`
- `lib/mobile/widgets/filter_chips.dart`
- `lib/mobile/widgets/genre_sheet.dart`
- `lib/mobile/widgets/home_header.dart`
- `lib/mobile/widgets/media_rows.dart`
- `lib/mobile/widgets/page_kit.dart`
- `lib/mobile/widgets/pill_button.dart`
- `lib/mobile/widgets/plus_card.dart`
- `lib/mobile/widgets/plus_sheets.dart`
- `lib/mobile/widgets/poster_card.dart`
- `lib/mobile/widgets/section_header.dart`
- `lib/mobile/widgets/telegram_channel_prompt.dart`
- `lib/screens/common/about.dart`
- `lib/screens/common/bookmark_screen.dart`
- `lib/screens/common/download_selection_sheets.dart`
- `lib/screens/common/downloads_screen.dart`
- `lib/screens/common/embedded_web_playback_screen.dart`
- `lib/screens/common/iptv_playlist_manager_dialog.dart`
- `lib/screens/common/live_tv_screen.dart`
- `lib/screens/common/player.dart`
- `lib/screens/common/player/player_episode_selection.dart`
- `lib/screens/common/player/player_external_subtitles.dart`
- `lib/screens/common/player/player_feedback_ui.dart`
- `lib/screens/common/player/player_local_subtitles.dart`
- `lib/screens/common/player/player_movie_recommendations.dart`
- `lib/screens/common/player/player_sheet_ui.dart`
- `lib/screens/common/player/player_subtitle_timing_sheet.dart`
- `lib/screens/common/player/player_watch_page.dart`
- `lib/screens/common/player/stream_feedback_prompt.dart`
- `lib/screens/common/player/tv_subtitle_timing_panel.dart`
- `lib/screens/common/player_settings.dart`
- `lib/screens/common/provider_choose.dart`
- `lib/screens/common/quickjs_source_settings_dialog.dart`
- `lib/screens/common/server_status_screen.dart`
- `lib/screens/common/settings.dart`
- `lib/screens/common/source_repositories_screen.dart`
- `lib/screens/common/update_screen.dart`
- `lib/screens/movie/collection_detail.dart`
- `lib/screens/user/edit_profile.dart`
- `lib/screens/user/login_screen.dart`
- `lib/screens/user/password_change.dart`
- `lib/screens/user/signup_screen.dart`
- `lib/screens/wellness/wellness_screen.dart`
- `lib/screens/wellness/widgets/insights_dashboard.dart`
- `lib/services/globle_method.dart`
- `lib/tv/focus/tv_focusable.dart`
- `lib/ui_components/in_app_message_dialog.dart`
- `lib/widgets/ad_block_playback_guard.dart`
- `lib/widgets/adsterra_playback_ad_screen.dart`
- `lib/widgets/common_widgets.dart`
- `lib/widgets/network_banner_widget.dart`
- `lib/widgets/playback_loading_screen.dart`
- `lib/widgets/vast_ad_overlay.dart`
- `test/mobile/mobile_nav_bar_test.dart`


Static validation record: `docs/build-reports/2026-11-15-phase63.19-navigation-feedback/STATIC_VALIDATION.md`.
