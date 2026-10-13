# Graph Report - client  (2026-10-13)

## Corpus Check
- 56 files · ~150,506 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2235 nodes · 3326 edges · 179 communities (119 shown, 60 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.88)
- Token cost: 1,200 input · 950 output

## Community Hubs (Navigation)
- client_config.dart
- notifications_screen.dart
- countdown_ring.dart
- sound_service.dart
- chat_screen.dart
- @pragma
- round_provider.dart
- home_screen.dart
- vote_screen.dart
- round.dart
- shop.dart
- round_result_screen.dart
- otp_screen.dart
- floating_letters_background.dart
- coin_burst.dart
- shop_screen.dart
- animated_name_effects.dart
- round_screen.dart
- ad_reward_provider.dart
- game_theme_extension.dart
- profile_screen.dart
- auth.dart
- cartoon_switch.dart
- create_join_room_screen.dart
- shop_provider.dart
- leaderboard_screen.dart
- scoreboard_screen.dart
- Route /
- router.dart
- notification_provider.dart
- myket_iap_store.dart
- round_count_picker_sheet.dart
- share_result_card.dart
- Route /login
- create_join_room_screen.dart
- socket_service.dart
- chat_provider.dart
- app_colors.dart
- app_images.dart
- AppDelegate.swift
- Route /chat
- auth_provider.dart
- tapsell_banner_ad.dart
- profile_screen.dart
- round_result_screen.dart
- iap_store.dart
- coin_pill.dart
- cartoon_progress_bar.dart
- room.dart
- shop_screen.dart
- Push Token Registration (/push-token)
- room_provider.dart
- round_result_screen.dart
- pill_tab_switcher.dart
- Leaderboard API (/leaderboard)
- auth_service.dart
- bazaar_iap_store.dart
- player_level.dart
- remote_config_provider.dart
- lobby_screen.dart
- settings_screen.dart
- p_text.dart
- game_history.dart
- player.dart
- ad_service.dart
- name_color.dart
- Route /otp
- persian_numbers.dart
- file
- scoring_display_test.dart
- rtl.dart
- splash_screen.dart
- confirm_dialog.dart
- insufficient_coins_dialog.dart
- timeout_bonus_dialog.dart
- analytics_provider.dart
- remote_config.dart
- main.dart
- leaderboard_provider.dart
- analytics_service.dart
- app_spacing.dart
- Auth
- client_config_test.dart
- app_back_button.dart
- reconnect_state_machine.dart
- Esmfamil Backend API
- nickname_screen.dart
- notification_service.dart
- player_identity_header.dart
- chat_screen.dart
- getLeaderboard(scope)
- socket_provider.dart
- home_screen.dart
- security_service.dart
- error_dialog.dart
- Cafe Bazaar / Poolakey store
- splash_provider.dart
- ad_reward_service.dart
- gradient_button.dart
- socket_provider.dart
- api_error.dart
- shop_service.dart
- player_avatar.dart
- lib/main.dart (Firebase init)
- category.dart
- room_events.dart
- iap_provider.dart
- cartoon_pedestal.dart
- Firebase Analytics
- remote_config_service.dart
- dio_client.dart
- Auth & OTP API
- ad_reward.dart
- Android client checklist
- room_provider.dart
- claimTimeoutBonus Event
- Errors
- fileinputstream
- bazaar_iap_store.dart
- audio_session dependency
- CLAUDE.md
- d_project_flutter_esmvafamil_client_ios_runner_generatedpluginregistrant_h
- hintResult Response
- firebase_messaging dependency
- flutter_poolakey dependency
- tapsell_mediation dependency
- flutter_lints ruleset
- 1000.png
- 2000.png
- 5000.png
- app_icon.png
- back.png
- chat.png
- coin.png
- gift-box.png
- hourglass.png
- ic_launcher.png
- Icon-App-1024x1024@1x.png
- Icon-App-20x20@1x.png
- Icon-App-20x20@2x.png
- Icon-App-20x20@3x.png
- Icon-App-29x29@1x.png
- Icon-App-29x29@2x.png
- Icon-App-29x29@3x.png
- Icon-App-40x40@1x.png
- Icon-App-40x40@2x.png
- Icon-App-40x40@3x.png
- Icon-App-60x60@2x.png
- Icon-App-60x60@3x.png
- Icon-App-76x76@1x.png
- Icon-App-76x76@2x.png
- Icon-App-83.5x83.5@2x.png
- Icon_with_notebook_and_pen_20260922193122-Photoroom.png
- LaunchImage.png
- LaunchImage@2x.png
- LaunchImage@3x.png
- light-bulb.png
- logo.png
- music.png
- notification.png
- play.png
- rank.png
- setting.png
- shopping-cart.png
- sound.png
- stop-watch.png
- team.png
- user.png
- warning.png
- Launch Screen Assets guide
- Community 172
- dio dependency
- firebase_analytics dependency
- firebase_core dependency
- flutter_launcher_icons dev dependency
- socket_io_client dependency
- esmvafamilyar Flutter project

## God Nodes (most connected - your core abstractions)
1. `soundServiceProvider` - 54 edges
2. `authControllerProvider` - 24 edges
3. `_` - 22 edges
4. `roundControllerProvider` - 17 edges
5. `build` - 17 edges
6. `roomControllerProvider` - 15 edges
7. `EsmVaFamilYarApp` - 13 edges
8. `_HomeScreenState` - 13 edges
9. `build` - 12 edges
10. `_` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Shop & Cosmetics (/shop/items, /purchase, /equip)` --references--> `ShopCategoryApi`  [INFERRED]
  Esmfamil API.md → lib/models/shop.dart
- `Leaderboard API (/leaderboard)` --references--> `LeaderboardScopeApi`  [INFERRED]
  Esmfamil API.md → lib/models/leaderboard.dart
- `Notifications & Push Endpoints (/notifications)` --references--> `NotificationService`  [INFERRED]
  Esmfamil API.md → lib/services/notification_service.dart
- `Push Token Registration (/push-token)` --references--> `PushService`  [INFERRED]
  Esmfamil API.md → lib/services/push_service.dart
- `Push Token Registration (/push-token)` --semantically_similar_to--> ``POST /notifications/push-token` — register device (player)`  [INFERRED] [semantically similar]
  Esmfamil API.md → notifications.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Dual-store IAP flavor pattern (Myket + Cafe Bazaar)** — myket_iap_integration_myketiap, myket_iap_integration_storeconfig, pubspec_myket_iap, pubspec_flutter_poolakey [INFERRED 0.80]
- **FCM push notification pipeline** — lib_services_push_service, lib_providers_push_provider, pubspec_firebase_messaging, pubspec_flutter_local_notifications [INFERRED 0.85]
- **Esmfamil Monetization Ecosystem (Shop, Coins, Rewarded Ads)** — esmfamil_api_shop, esmfamil_api_shop_coins, esmfamil_api_ads, esmfamil_api_ads_rescue [INFERRED 0.85]
- **Esmfamil Engagement & Communication Flow (Auth, Notifications, Push)** — esmfamil_api_auth, esmfamil_api_notifications, esmfamil_api_push_token, esmfamil_api_socket [INFERRED 0.85]

## Communities (179 total, 60 thin omitted)

### Community 0 - "client_config.dart"
Cohesion: 0.04
Nodes (50): adRescueBalanceThreshold, adRescueCoinAmount, adRescueMaxPerDay, adRewardCoinAmount, adRewardCooldownSeconds, adRewardMaxPerDay, _asInt, _asMap (+42 more)

### Community 1 - "notifications_screen.dart"
Cohesion: 0.04
Nodes (46): DateTime get, ChatMessage, createdAt, createdAtLocal, fromJson, id, nickname, playerId (+38 more)

### Community 2 - "countdown_ring.dart"
Cohesion: 0.05
Nodes (41): DateTime, AdRewardResult, AdRewardStatus, canWatch, code, coinAmount, coinBalance, cooldownEndsAt (+33 more)

### Community 3 - "sound_service.dart"
Cohesion: 0.05
Nodes (39): AudioPlayer, double get, _clickSound, _coinCollectSound, _configureSession, dispose, _effectContextSet, _effectPool (+31 more)

### Community 4 - "chat_screen.dart"
Cohesion: 0.05
Nodes (38): ChatMessage?, _buildBubble, _cancelReply, chars, _clock, code, _composer, createState (+30 more)

### Community 5 - "@pragma"
Cohesion: 0.05
Nodes (37): AndroidNotificationDetails get, @pragma, FirebaseMessaging?, FirebaseMessaging get, FlutterLocalNotificationsPlugin, _androidDetails, cancelNotification, _canScheduleDaily (+29 more)

### Community 6 - "round_provider.dart"
Cohesion: 0.06
Nodes (36): activeVote, at, castVote, claimTimeoutBonus, copyWith, currentRound, extraTimeUsed, finalScoreboard (+28 more)

### Community 7 - "home_screen.dart"
Cohesion: 0.06
Nodes (35): GlobalKey, badgeCount, code, _coinDestinationKey, _confirmExit, _controller, _CooldownLabel, _CooldownLabelState (+27 more)

### Community 8 - "vote_screen.dart"
Cohesion: 0.06
Nodes (34): VoteResult, category, color, createState, deadline, dispose, _height, icon (+26 more)

### Community 9 - "round.dart"
Cohesion: 0.06
Nodes (34): accepted, authorPlayerIds, avatarUrl, categories, category, copyWith, deadline, fromJson (+26 more)

### Community 10 - "shop.dart"
Cohesion: 0.06
Nodes (31): alreadyProcessed, avatarUrl, bazaarSku, category, code, coinAmount, coinBalance, CoinPurchaseResult (+23 more)

### Community 11 - "round_result_screen.dart"
Cohesion: 0.06
Nodes (31): _breakSeconds, category, color, _controller, createState, dispose, emoji, entry (+23 more)

### Community 12 - "otp_screen.dart"
Cohesion: 0.07
Nodes (30): bazaar,, build, _cooldownTimer, createState, dispose, _hasError, initState, _isSubmitting (+22 more)

### Community 13 - "floating_letters_background.dart"
Cohesion: 0.06
Nodes (30): CustomPainter, _CartoonRingPainter, build, child, color, _controller, createState, depth (+22 more)

### Community 14 - "coin_burst.dart"
Cohesion: 0.07
Nodes (29): Duration get, bow, build, _buildCoin, CoinBurst, _CoinBurstLayer, _CoinBurstLayerState, _coins (+21 more)

### Community 15 - "shop_screen.dart"
Cohesion: 0.07
Nodes (28): Key?, _buyCoinPack, _categories, coinBalance, _CoinBalanceBar, _CoinBalanceBarState, _coinBalanceKey, coinImageKey (+20 more)

### Community 16 - "animated_name_effects.dart"
Cohesion: 0.07
Nodes (27): CustomClipper, AnimatedNameEffect, build, _burst, _c, child, createState, dispose (+19 more)

### Community 17 - "round_screen.dart"
Cohesion: 0.07
Nodes (27): category, controller, _controllerFor, _controllers, _controllersForRound, createState, _currentHintCost, dispose (+19 more)

### Community 18 - "ad_reward_provider.dart"
Cohesion: 0.08
Nodes (26): AdRewardService, AdRewardStatus?, AdService, _adService, clearJustAwarded, coinsJustAwarded, _cooldownTimer, copyWith (+18 more)

### Community 19 - "game_theme_extension.dart"
Cohesion: 0.08
Nodes (25): app_colors.dart, app_spacing.dart, BuildContext, Color?, game_theme_extension.dart, GameTheme get, Gradient, AppTheme (+17 more)

### Community 20 - "profile_screen.dart"
Cohesion: 0.07
Nodes (26): IconData get, _AvatarOption, avatarUrl, busy, color, _ColorSwatch, controller, createState (+18 more)

### Community 21 - "auth.dart"
Cohesion: 0.07
Nodes (26): AuthSession, avatarUrl, code, coinBalance, copyWith, currentLevelScore, fromJson, gamesPlayed (+18 more)

### Community 22 - "cartoon_switch.dart"
Cohesion: 0.07
Nodes (25): build, CartoonSlider, _gold, _goldDeep, _goldLight, height, onChanged, onChangeEnd (+17 more)

### Community 23 - "create_join_room_screen.dart"
Cohesion: 0.12
Nodes (26): ConsumerState, ConsumerStatefulWidget, CreateJoinRoomScreen, _CreateJoinRoomScreenState, _CircleIconButton, _CircleIconButtonState, LeaderboardScreen, _LeaderboardScreenState (+18 more)

### Community 24 - "shop_provider.dart"
Cohesion: 0.08
Nodes (25): iap_provider.dart, ShopCatalog, _applyMutation, catalog, CoinPurchaseOutcome, CoinPurchaseResultStatus, copyWith, equip (+17 more)

### Community 25 - "leaderboard_screen.dart"
Cohesion: 0.08
Nodes (25): _at, color, createState, delay, dispose, _EmptyState, entry, initState (+17 more)

### Community 26 - "scoreboard_screen.dart"
Cohesion: 0.08
Nodes (25): _at, categoriesPerRound, color, compact, createState, delay, entry, icon (+17 more)

### Community 27 - "Route /"
Cohesion: 0.11
Nodes (25): roomControllerProvider, roundControllerProvider, _join, _handleCreate, _handleJoin, build, _confirmDeleteRoom, _submit (+17 more)

### Community 28 - "router.dart"
Cohesion: 0.08
Nodes (23): GoRouter, refreshNotifier, rootNavigatorKey, routeObserver, NavigatorState, PageRoute, screens/chat_screen.dart, screens/create_join_room_screen.dart (+15 more)

### Community 29 - "notification_provider.dart"
Cohesion: 0.09
Nodes (23): copyWith, error, hasMore, isLoading, isLoadingMore, items, load, loadMore (+15 more)

### Community 30 - "myket_iap_store.dart"
Cohesion: 0.08
Nodes (23): configure, consume, disconnect, _ensureInitialized, _formatMyketError, id, _init, _initialized (+15 more)

### Community 31 - "round_count_picker_sheet.dart"
Cohesion: 0.09
Nodes (23): build, _cardFill, coinCost, _controller, count, createState, dispose, _fillOff (+15 more)

### Community 32 - "share_result_card.dart"
Cohesion: 0.09
Nodes (22): dart:typed_data, dart:ui, ScoreboardEntry, boundary, boundaryKey, build, byteData, _captureBoundary (+14 more)

### Community 33 - "Route /login"
Cohesion: 0.09
Nodes (22): apply, BackgroundMusic, backgroundMusicProvider, didChangeAppLifecycleState, music, _MusicLifecycleObserver, musicVolumeProvider, observer (+14 more)

### Community 34 - "create_join_room_screen.dart"
Cohesion: 0.10
Nodes (21): ../config/coin_costs.dart, _codeController, createState, dispose, initState, _isSubmitting, isValidRoomCode, _JoinTab (+13 more)

### Community 35 - "socket_service.dart"
Cohesion: 0.09
Nodes (21): ConnectionStatus get, _attachHandlers, connect, disconnect, dispose, emit, _isAuthError, isConnected (+13 more)

### Community 36 - "chat_provider.dart"
Cohesion: 0.10
Nodes (21): ChatController, ChatState, chatUnreadCountProvider, consumeError, copyWith, hasLoadedHistory, lastError, markScreenOpen (+13 more)

### Community 37 - "app_colors.dart"
Cohesion: 0.09
Nodes (21): AppColors, darkBackground, darkBorder, darkSurface, darkSurfaceElevated, darkTextPrimary, darkTextSecondary, emerald (+13 more)

### Community 38 - "app_images.dart"
Cohesion: 0.09
Nodes (21): AppImages, back, chat, coin, coinPackByAmount, coinPackImage, giftBox, hourglass (+13 more)

### Community 39 - "AppDelegate.swift"
Cohesion: 0.10
Nodes (15): Any, FirebaseCore, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+7 more)

### Community 40 - "Route /chat"
Cohesion: 0.12
Nodes (21): authControllerProvider, chatUnreadCountProvider, connectionStatusProvider, giftBoxControllerProvider, build, _fireCoinAnimation, HomeScreen, _HomeScreenState (+13 more)

### Community 41 - "auth_provider.dart"
Cohesion: 0.10
Nodes (20): AuthPlayer, AuthController, authServiceProvider, AuthState, AuthStatus, copyWith, initial, logout (+12 more)

### Community 42 - "tapsell_banner_ad.dart"
Cohesion: 0.10
Nodes (19): BannerPosition, _adId, bannerPosition, build, createState, _destroyBanner, didChangeDependencies, didPopNext (+11 more)

### Community 43 - "profile_screen.dart"
Cohesion: 0.16
Nodes (20): adRewardServiceProvider, adServiceProvider, authControllerProvider, recentGamesProvider, leaderboardProvider, remoteConfigValueProvider, build, _LeaderboardTab (+12 more)

### Community 44 - "round_result_screen.dart"
Cohesion: 0.10
Nodes (20): _SendButton, _StatusChip, _Stand, _StatCard, _CategoryResultCard, _FloatingReactionWidget, _JudgementRow, _ScoreRow (+12 more)

### Community 45 - "iap_store.dart"
Cohesion: 0.10
Nodes (20): _, cancelled, configure, consume, dataSignature, disconnect, error, failed (+12 more)

### Community 46 - "coin_pill.dart"
Cohesion: 0.10
Nodes (19): animated, balance, build, compact, _compactHeight, createState, didUpdateWidget, dispose (+11 more)

### Community 47 - "cartoon_progress_bar.dart"
Cohesion: 0.11
Nodes (18): Animation, dart:math, Duration, build, _controller, createState, didUpdateWidget, dispose (+10 more)

### Community 48 - "room.dart"
Cohesion: 0.11
Nodes (18): category.dart, categories, code, currentRoundIndex, fromJson, hostId, isOnlineGame, isSoloGame (+10 more)

### Community 49 - "shop_screen.dart"
Cohesion: 0.18
Nodes (19): ConsumerWidget, shopControllerProvider, soundServiceProvider, _ErrorState, _ActionChip, LobbyScreen, _AppearanceSection, initState (+11 more)

### Community 50 - "Push Token Registration (/push-token)"
Cohesion: 0.11
Nodes (18): dart:io, Push Token Registration (/push-token), fgSub, platform, push, pushServiceProvider, refreshInbox, register (+10 more)

### Community 51 - "room_provider.dart"
Cohesion: 0.11
Nodes (18): copyWith, createOnlineGame, createRoom, initial, isBusy, joinRoom, leaveRoom, myPlayerId (+10 more)

### Community 52 - "round_result_screen.dart"
Cohesion: 0.15
Nodes (19): _NextRoundCountdown, _NextRoundCountdownState, _ReactionButton, _ReactionButtonState, _CategoryField, _CategoryFieldState, _GlitchText, _GlitchTextState (+11 more)

### Community 53 - "pill_tab_switcher.dart"
Cohesion: 0.11
Nodes (18): activeBorder, activeBottom, activeTop, build, controller, divider, icon, inactiveText (+10 more)

### Community 54 - "Leaderboard API (/leaderboard)"
Cohesion: 0.12
Nodes (17): Leaderboard API (/leaderboard), apiValue, avatarUrl, entries, fromJson, labelFa, LeaderboardEntry, LeaderboardResult (+9 more)

### Community 55 - "auth_service.dart"
Cohesion: 0.12
Nodes (16): FlutterSecureStorage, AuthService, clearSession, _dio, fetchMe, fetchRecentGames, readStoredToken, requestOtp (+8 more)

### Community 56 - "bazaar_iap_store.dart"
Cohesion: 0.12
Nodes (16): Future, iap_store.dart, configure, _connect, _connected, _connecting, consume, disconnect (+8 more)

### Community 57 - "player_level.dart"
Cohesion: 0.12
Nodes (15): createRoomCostProvider, joinRoomCostProvider, onlineGameCostProvider, watch, build, _CreateTab, currentLevelFloor, fromScore (+7 more)

### Community 58 - "remote_config_provider.dart"
Cohesion: 0.13
Nodes (16): config, initial, load, RemoteConfigController, remoteConfigServiceProvider, RemoteConfigState, RemoteConfigStatus, _service (+8 more)

### Community 59 - "lobby_screen.dart"
Cohesion: 0.12
Nodes (16): code, _FillingLobbyIndicator, icon, label, onTap, player, _PlayerTile, roomCode (+8 more)

### Community 60 - "settings_screen.dart"
Cohesion: 0.12
Nodes (15): double?, asset, bottomPadding, _CardIcon, _CartoonCard, child, enabled, _MusicVolumeTile (+7 more)

### Community 61 - "p_text.dart"
Cohesion: 0.12
Nodes (15): InlineSpan?, build, data, maxLines, overflow, PText, rich, softWrap (+7 more)

### Community 62 - "game_history.dart"
Cohesion: 0.13
Nodes (15): int?, coinsEarned, finishedAt, fromApi, fromJson, GameHistoryEntry, GameMode, GameModeApi (+7 more)

### Community 63 - "player.dart"
Cohesion: 0.12
Nodes (15): avatarId, avatarUrl, connected, cosmetics, frameId, fromJson, id, isHost (+7 more)

### Community 64 - "ad_service.dart"
Cohesion: 0.12
Nodes (15): AdService, AdWatchResult, _busyRetryDelay, _consentSet, _dbgZoneId, _ensureConsent, _ensureLegacyAdapter, isConfigured (+7 more)

### Community 65 - "name_color.dart"
Cohesion: 0.12
Nodes (15): build, ColoredName, colorHex, maxLines, name, overflow, parsed, parseNameColor (+7 more)

### Community 66 - "Route /otp"
Cohesion: 0.14
Nodes (14): _asciiPhone, build, createState, dispose, _isSubmitting, LoginScreen, _LoginScreenState, _phoneController (+6 more)

### Community 67 - "persian_numbers.dart"
Cohesion: 0.14
Nodes (14): AsciiDigits, formatEditUpdate, persianCounter, PersianDigitInputFormatter, PersianDigits, PersianDigitsNum, text, toAsciiDigits (+6 more)

### Community 68 - "file"
Cohesion: 0.22
Nodes (7): MainActivity, Bundle, file, FlutterActivity, FlutterEngine, methodchannel, windowcompat

### Community 69 - "scoring_display_test.dart"
Cohesion: 0.14
Nodes (13): WordVerdict, List, package:esmvafamilyar/models/category.dart, package:esmvafamilyar/models/round.dart, package:esmvafamilyar/utils/scoring_display.dart, category, judgement, main (+5 more)

### Community 70 - "rtl.dart"
Cohesion: 0.18
Nodes (11): connectionStatusProvider, build, child, ForceRtl, build, ConnectionStatusBar, build, NpcBadge (+3 more)

### Community 71 - "splash_screen.dart"
Cohesion: 0.21
Nodes (12): ChangeNotifier, remoteConfigProvider, splashReadyProvider, _AuthRefreshNotifier, build, createState, initState, SplashScreen (+4 more)

### Community 72 - "confirm_dialog.dart"
Cohesion: 0.15
Nodes (12): build, cancelLabel, confirmLabel, destructive, _DialogButton, gradient, _height, label (+4 more)

### Community 73 - "insufficient_coins_dialog.dart"
Cohesion: 0.15
Nodes (12): _adError, _busy, createState, _DialogButton, enabled, gradient, _height, label (+4 more)

### Community 74 - "timeout_bonus_dialog.dart"
Cohesion: 0.15
Nodes (12): _ActionButton, build, _busy, createState, enabled, _errorMessage, gradient, label (+4 more)

### Community 75 - "analytics_provider.dart"
Cohesion: 0.18
Nodes (10): auth_provider.dart, analytics, analyticsServiceProvider, playerId, read, token, AnalyticsService, ../models/game_history.dart (+2 more)

### Community 76 - "remote_config.dart"
Cohesion: 0.17
Nodes (11): client_config.dart, ClientConfig, bazaarRsaPublicKey, config, empty, fromJson, myketRsaPublicKey, RemoteConfig (+3 more)

### Community 77 - "main.dart"
Cohesion: 0.17
Nodes (11): dart:async, ../firebase_options.dart, main, package:flutter_localizations/flutter_localizations.dart, ../providers/ad_reward_provider.dart, providers/analytics_provider.dart, ../providers/chat_provider.dart, providers/push_provider.dart (+3 more)

### Community 78 - "leaderboard_provider.dart"
Cohesion: 0.18
Nodes (10): Dio, fetch, leaderboardServiceProvider, service, token, _dio, fetch, LeaderboardService (+2 more)

### Community 79 - "analytics_service.dart"
Cohesion: 0.17
Nodes (11): FirebaseAnalytics, FirebaseAnalyticsObserver get, analytics, coinsPurchased, gameStarted, logEvent, rewardedAdCompleted, roundFinished (+3 more)

### Community 80 - "app_spacing.dart"
Cohesion: 0.17
Nodes (11): AppRadius, AppSpacing, lg, md, minTouchTarget, screenPadding, sm, xl (+3 more)

### Community 81 - "Auth"
Cohesion: 0.18
Nodes (12): Auth, Config (`.env`), `GET /notifications` — list (player), `GET /notifications/unread-count` — badge (player), In-App Notifications API, Model, Operator form (HTML), Paging (+4 more)

### Community 82 - "client_config_test.dart"
Cohesion: 0.17
Nodes (9): package:esmvafamilyar/models/client_config.dart, package:esmvafamilyar/models/remote_config.dart, package:esmvafamilyar/services/iap/store_config.dart, package:esmvafamilyar/services/reconnect_state_machine.dart, package:esmvafamilyar/services/socket_service.dart, package:flutter_test/flutter_test.dart, main, main (+1 more)

### Community 83 - "app_back_button.dart"
Cohesion: 0.18
Nodes (10): AnimationController, build, _controller, createState, dispose, _handleTap, initState, onPressed (+2 more)

### Community 84 - "reconnect_state_machine.dart"
Cohesion: 0.18
Nodes (10): bool get, int get, _attempts, endSession, _hasActiveSession, maxAttempts, onStatusChange, ReconnectStateMachine (+2 more)

### Community 85 - "Esmfamil Backend API"
Cohesion: 0.18
Nodes (10): Esmfamil Backend API, Rewarded Ads API (/ads/reward-status, /reward), Rescue Ad Reward (/ads/rescue-status, /reward/rescue), Admin Anti-Cheat API (/admin-api/suspects, /player), Client Configuration & SDK Keys (/config/client), Notifications & Push Endpoints (/notifications), Shop & Cosmetics (/shop/items, /purchase, /equip), IAP Coin Verification (/shop/purchase/coins) (+2 more)

### Community 86 - "nickname_screen.dart"
Cohesion: 0.20
Nodes (10): build, _controller, createState, dispose, _isSubmitting, NicknameScreen, _NicknameScreenState, package:go_router/go_router.dart (+2 more)

### Community 87 - "notification_service.dart"
Cohesion: 0.18
Nodes (10): _auth, _dio, fetchPage, fetchUnreadCount, markAllRead, markRead, registerPushToken, _toException (+2 more)

### Community 88 - "player_identity_header.dart"
Cohesion: 0.18
Nodes (10): avatarRadius, avatarUrl, build, level, _LevelBadge, nameColorHex, nickname, PlayerIdentityHeader (+2 more)

### Community 89 - "chat_screen.dart"
Cohesion: 0.22
Nodes (10): chatControllerProvider, activate, build, ChatScreen, _ChatScreenState, deactivate, dispose, initState (+2 more)

### Community 90 - "getLeaderboard(scope)"
Cohesion: 0.20
Nodes (9): getLeaderboard(scope), getPlayerRank(scope, playerId), GET /leaderboard endpoint, src/routes/leaderboard.ts, myRank field semantics, Why no pagination (fixed Top 100 design), src/db/playerRepository.ts, src/middleware/rateLimit.ts (+1 more)

### Community 91 - "socket_provider.dart"
Cohesion: 0.36
Nodes (10): build, EsmVaFamilYarApp, analyticsUserSyncProvider, chatControllerProvider, pushControllerProvider, socketAutoConnectProvider, socketReconnectResyncProvider, unauthorizedSocketWatcherProvider (+2 more)

### Community 92 - "home_screen.dart"
Cohesion: 0.20
Nodes (10): _JoinFromChatButton, _JoinFromChatButtonState, _jumpToMessage, _startReply, _GiftBoxButton, _GiftBoxButtonState, _handleTap, _HeroButton (+2 more)

### Community 93 - "security_service.dart"
Cohesion: 0.20
Nodes (9): build, _channel, _isChecking, isDeviceRooted, _RootWarningDialog, SecurityService, verifyDeviceIntegrity, static bool (+1 more)

### Community 94 - "error_dialog.dart"
Cohesion: 0.20
Nodes (9): build, _DialogButton, _height, label, message, onTap, show, title (+1 more)

### Community 95 - "Cafe Bazaar / Poolakey store"
Cohesion: 0.20
Nodes (10): Cafe Bazaar / Poolakey store, New flavor hangs on splash screen (flutter_assets bug), IabResult class, Inventory class, MyketBillingService wrapper, MyketIAP API (static), Poolakey duplicate-class AAR stripping, ProGuard/R8 rules for Myket billing (+2 more)

### Community 96 - "splash_provider.dart"
Cohesion: 0.22
Nodes (8): ad_reward_provider.dart, authResolved, authStatus, configReady, giftBoxLoaded, minTimeElapsed, needGiftBox, remote_config_provider.dart

### Community 97 - "ad_reward_service.dart"
Cohesion: 0.22
Nodes (8): api_error.dart, AdRewardService, claimRescueReward, claimReward, _dio, fetchStatus, _toException, ../models/ad_reward.dart

### Community 98 - "gradient_button.dart"
Cohesion: 0.22
Nodes (8): IconData, build, gradient, icon, isLoading, label, onTap, package:animated_button/animated_button.dart

### Community 99 - "socket_provider.dart"
Cohesion: 0.22
Nodes (8): connectedWithToken, hasSeenDisconnect, service, socketServiceProvider, ConnectionStatus, SocketService, room_provider.dart, ../services/socket_service.dart

### Community 100 - "api_error.dart"
Cohesion: 0.22
Nodes (8): ApiError, code, from, _genericError, _genericUnreachable, _maxMessageLen, message, static const

### Community 101 - "shop_service.dart"
Cohesion: 0.22
Nodes (8): _dio, equip, fetchItems, purchase, purchaseCoins, ShopService, _toShopException, ../models/shop.dart

### Community 102 - "player_avatar.dart"
Cohesion: 0.22
Nodes (8): avatarUrl, build, _defaultAvatarPath, _initials, name, PlayerAvatar, radius, ../theme/app_theme.dart

### Community 103 - "lib/main.dart (Firebase init)"
Cohesion: 0.25
Nodes (7): lib/main.dart (Firebase init), android, DefaultFirebaseOptions, ios, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 104 - "category.dart"
Cohesion: 0.29
Nodes (7): CategoryId, CategoryIdX, fromWire, wireId, package:flutter/widgets.dart, package:lucide_icons/lucide_icons.dart, String get

### Community 105 - "room_events.dart"
Cohesion: 0.25
Nodes (7): balance, code, fromJson, InsufficientCoinsInfo, message, required, toString

### Community 106 - "iap_provider.dart"
Cohesion: 0.25
Nodes (7): iapStoreProvider, store, return, ../services/iap/bazaar_iap_store.dart, ../services/iap/iap_store.dart, ../services/iap/myket_iap_store.dart, ../services/iap/store_config.dart

### Community 107 - "cartoon_pedestal.dart"
Cohesion: 0.25
Nodes (7): build, CartoonPedestal, color, height, _outline, rank, ../utils/persian_numbers.dart

### Community 108 - "Firebase Analytics"
Cohesion: 0.29
Nodes (7): Firebase Analytics, Firebase Cloud Messaging (FCM), Firebase project esmfamil-87855, android/app/google-services.json, ios/Runner/GoogleService-Info.plist, In-app /notifications REST API fallback, lib/router.dart (screen_view logging)

### Community 109 - "remote_config_service.dart"
Cohesion: 0.33
Nodes (5): dio_client.dart, _dio, fetch, RemoteConfigService, ../models/remote_config.dart

### Community 110 - "dio_client.dart"
Cohesion: 0.33
Nodes (5): buildDio, _fallbackBaseUrl, resolved, package:dio/dio.dart, package:flutter_dotenv/flutter_dotenv.dart

### Community 111 - "Auth & OTP API"
Cohesion: 0.40
Nodes (5): Auth & OTP API, OTP Authentication (/request-otp & /verify-otp), Nickname Management (/set-nickname), Player Profile & History (/me, /me/games), Rate Limiting Policy

### Community 112 - "ad_reward.dart"
Cohesion: 0.40
Nodes (5): Exception, AdRewardException, AuthException, RoomException, ShopException

### Community 113 - "Android client checklist"
Cohesion: 0.40
Nodes (5): Android client checklist, `DELETE /notifications/push-token` — unregister device (player), Push notifications (Firebase Cloud Messaging), Send response, Server setup

### Community 114 - "room_provider.dart"
Cohesion: 0.50
Nodes (4): Event, RoomController, RoomControllerState, Payload

### Community 115 - "claimTimeoutBonus Event"
Cohesion: 0.50
Nodes (4): claimTimeoutBonus Event, extraTimeGranted Response, timeoutBonusGranted Response, useExtraTime Event

### Community 116 - "Errors"
Cohesion: 0.50
Nodes (4): Errors, Example, `POST /notifications` — send (operator), Response `201`

### Community 118 - "bazaar_iap_store.dart"
Cohesion: 0.67
Nodes (3): BazaarIapStore, IapStore, MyketIapStore

### Community 119 - "audio_session dependency"
Cohesion: 0.67
Nodes (3): audio_session dependency, audioplayers dependency, just_audio dependency

## Ambiguous Edges - Review These
- `src/routes/leaderboard.ts` → `src/db/playerRepository.ts`  [AMBIGUOUS]
  leaderboard.md · relation: calls

## Knowledge Gaps
- **1437 isolated node(s):** `adRescueBalanceThreshold`, `adRescueCoinAmount`, `adRescueMaxPerDay`, `adRewardCoinAmount`, `adRewardCooldownSeconds` (+1432 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1610 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **60 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `src/routes/leaderboard.ts` and `src/db/playerRepository.ts`?**
  _Edge tagged AMBIGUOUS (relation: calls) - confidence is low._
- **Why does `_` connect `iap_store.dart` to `category.dart`, `reconnect_state_machine.dart`, `bazaar_iap_store.dart`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `RoomException` connect `ad_reward.dart` to `room_events.dart`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `NotificationService` connect `Esmfamil Backend API` to `notification_provider.dart`, `notification_service.dart`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `adRescueBalanceThreshold`, `adRescueCoinAmount`, `adRescueMaxPerDay` to the rest of the system?**
  _1437 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `client_config.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0392156862745098 - nodes in this community are weakly interconnected._
- **Should `notifications_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04421768707482993 - nodes in this community are weakly interconnected._