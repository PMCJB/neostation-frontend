import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:neostation/services/sfx_service.dart';

import '../models/game_model.dart';
import '../models/system_model.dart';
import 'game_view_mode_dropdown.dart';
import '../sync/i_sync_provider.dart';
import '../themes/corner_radii.dart';
import 'game_action_button.dart';
import 'neo_sync_status_icon.dart';

/// Vertical action button column shared by the game list, grid, and carousel.
///
/// Renders back, favorite, random, view-mode, scrape (when available), and a
/// compact NeoSync status icon. Each button uses the tall badge-on-top layout
/// from [GameActionButton].
class GameActionButtons extends StatelessWidget {
  final SystemModel system;
  final GameModel? selectedGame;
  final ISyncProvider? syncProvider;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onRandom;
  final VoidCallback onViewMode;
  final VoidCallback? onScrape;
  final bool hasScreenScraper;
  final bool isScraping;
  final bool isDescriptionMissing;

  const GameActionButtons({
    super.key,
    required this.system,
    this.selectedGame,
    this.syncProvider,
    required this.onBack,
    required this.onFavorite,
    required this.onRandom,
    required this.onViewMode,
    this.onScrape,
    this.hasScreenScraper = false,
    this.isScraping = false,
    this.isDescriptionMissing = true,
  });

  @override
  Widget build(BuildContext context) {
    final selectedGame = this.selectedGame;
    final syncProvider = this.syncProvider;

    return Container(
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius:
            Theme.of(context).extension<CornerRadii>()?.radiusExternal ??
            BorderRadius.circular(14.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.r,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameActionButton(
            iconPath: 'assets/images/gamepad/Xbox_B_button.png',
            symbol: Symbols.arrow_back_rounded,
            color: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onTap: onBack,
          ),
          SizedBox(height: 6.r),
          GameActionButton(
            iconPath: 'assets/images/gamepad/Xbox_Y_button.png',
            symbol: Symbols.favorite_rounded,
            color: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onTap: selectedGame != null ? onFavorite : null,
          ),
          SizedBox(height: 6.r),
          GameActionButton(
            iconPath: 'assets/images/gamepad/Left Stick Click.png',
            symbol: Symbols.casino_rounded,
            color: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onTap: onRandom,
          ),
          SizedBox(height: 6.r),
          GameActionButton(
            iconPath: 'assets/images/gamepad/Xbox_X_button.png',
            symbol: Symbols.grid_view_rounded,
            color: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onTap: () {
              SfxService().playNavSound();
              GameViewModeDropdown.globalKey.currentState?.showDropdown();
            },
          ),
          if (hasScreenScraper && selectedGame != null && onScrape != null) ...[
            SizedBox(height: 6.r),
            GameActionButton(
              iconPath: 'assets/images/gamepad/Xbox_View_button.png',
              symbol:
                  isDescriptionMissing
                      ? Symbols.search_rounded
                      : Symbols.refresh_rounded,
              color: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              onTap: onScrape,
              isLoading: isScraping,
            ),
          ],
          // Compact NeoSync status indicator, separated from the main
          // action buttons and showing only a descriptive icon.
          if (syncProvider != null && selectedGame != null) ...[
            SizedBox(height: 12.r),
            NeoSyncStatusIcon(
              system: system,
              game: selectedGame,
              syncProvider: syncProvider,
              size: 24.0,
            ),
          ],
        ],
      ),
    );
  }
}
