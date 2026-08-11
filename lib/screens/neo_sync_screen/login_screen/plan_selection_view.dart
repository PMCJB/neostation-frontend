import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:neostation/l10n/app_locale.dart';
import 'package:neostation/models/billing_models.dart';
import 'package:neostation/models/user.dart';
import 'package:neostation/services/neosync/auth_service.dart';
import 'package:neostation/services/neosync/billing_service.dart';
import 'package:neostation/utils/gamepad_nav.dart';
import 'package:neostation/services/gamepad/gamepad_navigation_manager.dart';
import '../../app_screen.dart';
import 'neo_sync_shared.dart';

/// Full-screen plan selection view.
///
/// Shows the available NeoSync plans in a gamepad-navigable grid (left/right to
/// browse, A to upgrade or end the current subscription). Replaces the previous
/// upgrade dialog with a full view that has its own navigation layer.
class PlanSelectionView extends StatefulWidget {
  final List<PlanInfo> initialPlans;
  final Function(String, String) onUpgrade;
  final Function() onCancel;
  final IconData Function(String) getPlanIcon;
  final VoidCallback onBack;

  const PlanSelectionView({
    super.key,
    required this.initialPlans,
    required this.onUpgrade,
    required this.onCancel,
    required this.getPlanIcon,
    required this.onBack,
  });

  @override
  State<PlanSelectionView> createState() => _PlanSelectionViewState();
}

class _PlanSelectionViewState extends State<PlanSelectionView> {
  late GamepadNavigation _gamepadNav;
  List<PlanInfo> _plans = [];
  bool _plansLoading = true;
  String? _errorMessage;
  int _selectedPlanIndex = 0;

  void _navigatePlanLeft() {
    final availablePlans = _plans.where((plan) => plan.name != 'free').toList();
    if (availablePlans.isNotEmpty) {
      setState(() {
        _selectedPlanIndex = _selectedPlanIndex > 0
            ? _selectedPlanIndex - 1
            : availablePlans.length - 1;
      });
    }
  }

  void _navigatePlanRight() {
    final availablePlans = _plans.where((plan) => plan.name != 'free').toList();
    if (availablePlans.isNotEmpty) {
      setState(() {
        _selectedPlanIndex = (_selectedPlanIndex + 1) % availablePlans.length;
      });
    }
  }

  void _selectCurrentPlan() {
    final availablePlans = _plans.where((plan) => plan.name != 'free').toList();
    if (availablePlans.isNotEmpty &&
        _selectedPlanIndex < availablePlans.length) {
      final selectedPlan = availablePlans[_selectedPlanIndex];
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      final isCurrentPlan = user?.plan == selectedPlan.name;

      if (isCurrentPlan) {
        widget.onCancel();
      } else {
        widget.onUpgrade(selectedPlan.name, 'monthly');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _plans = widget.initialPlans;
    _gamepadNav = GamepadNavigation(
      onNavigateLeft: (isRepeat) => _navigatePlanLeft(),
      onNavigateRight: (isRepeat) => _navigatePlanRight(),
      onSelectItem: _selectCurrentPlan,
      onBack: () {
        if (mounted) widget.onBack();
      },
      onPreviousTab: () => AppNavigation.previousTab(),
      onNextTab: () => AppNavigation.nextTab(),
      onSettings: () {},
    );
    _loadPlans();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gamepadNav.initialize();
      GamepadNavigationManager.pushLayer(
        'neo_sync_plans',
        onActivate: () => _gamepadNav.activate(),
        onDeactivate: () => _gamepadNav.deactivate(),
      );
    });
  }

  @override
  void dispose() {
    GamepadNavigationManager.popLayer('neo_sync_plans');
    _gamepadNav.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) return;

    setState(() {
      _plansLoading = true;
      _errorMessage = null;
    });

    final billingService = Provider.of<BillingService>(context, listen: false);
    final result = await billingService.getAvailablePlans();

    if (mounted) {
      setState(() {
        _plansLoading = false;
        if (result['success']) {
          _plans = result['plans'];
          const planOrder = ['free', 'micro', 'mini', 'mega', 'ultra'];
          _plans.sort((a, b) {
            final aIndex = planOrder.indexOf(a.name);
            final bIndex = planOrder.indexOf(b.name);
            final aOrder = aIndex == -1 ? planOrder.length : aIndex;
            final bOrder = bIndex == -1 ? planOrder.length : bIndex;
            return aOrder.compareTo(bOrder);
          });
          final availablePlans = _plans
              .where((plan) => plan.name != 'free')
              .toList();
          if (availablePlans.isNotEmpty) {
            _selectedPlanIndex = 0;
          }
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }

  bool _isUpgrade(String? currentPlan, String targetPlan) {
    if (currentPlan == null ||
        currentPlan.isEmpty ||
        currentPlan.toLowerCase().trim() == 'free') {
      return true;
    }

    const planOrder = ['free', 'micro', 'mini', 'mega', 'ultra'];
    final current = currentPlan.toLowerCase().trim();
    final target = targetPlan.toLowerCase().trim();

    int currentIndex = -1;
    int targetIndex = -1;

    for (int i = 0; i < planOrder.length; i++) {
      if (current.contains(planOrder[i])) currentIndex = i;
      if (target.contains(planOrder[i])) targetIndex = i;
    }

    if (currentIndex == -1) return true;
    if (targetIndex == -1) return false;

    return targetIndex > currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return Padding(
      padding: EdgeInsets.only(top: 52.r, left: 8.r, right: 8.r, bottom: 8.r),
      child: Column(
        children: [
          NeoSyncSectionHeader(
            icon: Symbols.payment_rounded,
            title: AppLocale.manageYourPlan
                .getString(context)
                .replaceFirst('{plan}', user?.plan.toUpperCase() ?? ''),
          ),
          SizedBox(height: 8.r),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  width: 1.r,
                ),
              ),
              child: _buildPlansContent(context, user),
            ),
          ),
          SizedBox(height: 6.r),
          Align(
            alignment: Alignment.centerRight,
            child: NeoSyncBackButton(onTap: () => widget.onBack()),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansContent(BuildContext context, User? currentUser) {
    final theme = Theme.of(context);
    final currentPlan = currentUser?.plan;

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 48.r,
            ),
            SizedBox(height: 8.r),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 12.r,
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.r),
            ElevatedButton.icon(
              onPressed: _loadPlans,
              icon: Icon(Symbols.refresh_rounded, size: 16.r),
              label: Text(AppLocale.retry.getString(context)),
            ),
          ],
        ),
      );
    }

    if (_plansLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            SizedBox(height: 8.r),
            Text(
              AppLocale.loadingPlans.getString(context),
              style: TextStyle(
                fontSize: 12.r,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.payment_rounded,
              size: 48.r,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(height: 8.r),
            Text(
              AppLocale.noPlansAvailable.getString(context),
              style: TextStyle(
                fontSize: 12.r,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 8.r),
            ElevatedButton.icon(
              onPressed: _loadPlans,
              icon: Icon(Symbols.refresh_rounded, size: 16.r),
              label: Text(AppLocale.retry.getString(context)),
            ),
          ],
        ),
      );
    }

    final availablePlans = _plans.where((plan) => plan.name != 'free').toList();

    return ListView.builder(
      itemCount: availablePlans.length,
      itemBuilder: (context, index) {
        final plan = availablePlans[index];
        final isCurrentPlan = currentPlan == plan.name;
        final isSelectedPlan = index == _selectedPlanIndex;

        return Padding(
          padding: EdgeInsets.only(bottom: 8.r),
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: isSelectedPlan
                  ? theme.colorScheme.secondary.withValues(alpha: 0.08)
                  : isCurrentPlan
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelectedPlan
                    ? theme.colorScheme.secondary.withValues(alpha: 0.8)
                    : isCurrentPlan
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                width: (isCurrentPlan || isSelectedPlan) ? 2.r : 1.r,
              ),
            ),
            child: Row(
              children: [
                // Plan icon
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    widget.getPlanIcon(plan.name),
                    color: theme.colorScheme.primary,
                    size: 24.r,
                  ),
                ),
                SizedBox(width: 12.r),
                // Name + storage + prices
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontSize: 11.r,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentPlan) ...[
                            SizedBox(width: 6.r),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.r,
                                vertical: 2.r,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                AppLocale.currentBadge.getString(context),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 6.r,
                                  letterSpacing: 0.5.r,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.r),
                      Row(
                        children: [
                          Icon(
                            Symbols.cloud_rounded,
                            size: 10.r,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          SizedBox(width: 4.r),
                          Text(
                            plan.storageQuotaFormatted,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                              fontSize: 9.r,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.r),
                      Text(
                        '\$${plan.priceMonthly.toStringAsFixed(2)}/${AppLocale.monthly.getString(context)} · \$${plan.priceYearly.toStringAsFixed(2)}/${AppLocale.yearly.getString(context)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 8.r,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.r),
                // Action button
                if (!isCurrentPlan) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onUpgrade(plan.name, 'monthly');
                    },
                    icon: Image.asset(
                      'assets/images/gamepad/Xbox_A_button.png',
                      width: 18.r,
                      height: 18.r,
                      color: theme.colorScheme.onPrimary,
                    ),
                    label: Text(
                      _isUpgrade(currentPlan, plan.name)
                          ? AppLocale.upgrade.getString(context)
                          : AppLocale.downgrade.getString(context),
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 10.r,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8.r),
                      elevation: 0,
                    ),
                  ),
                ] else if (currentUser?.stripeSubscriptionStatus == 'canceling') ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocale.subscriptionEnding.getString(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontSize: 7.r,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2.r),
                      Text(
                        AppLocale.endsOn
                            .getString(context)
                            .replaceFirst(
                              '{date}',
                              currentUser?.subscriptionEndDateFormatted ?? 'N/A',
                            ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 6.r,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocale.renewsOn
                            .getString(context)
                            .replaceFirst(
                              '{date}',
                              currentUser?.subscriptionEndDateFormatted ?? 'N/A',
                            ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 7.r,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4.r),
                      OutlinedButton.icon(
                        onPressed: () {
                          widget.onCancel();
                        },
                        icon: Image.asset(
                          'assets/images/gamepad/Xbox_A_button.png',
                          width: 16.r,
                          height: 16.r,
                          color: theme.colorScheme.error,
                        ),
                        label: Text(
                          AppLocale.endSubscription.getString(context),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 9.r,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: theme.colorScheme.error.withValues(alpha: 0.5),
                            width: 1.r,
                          ),
                          foregroundColor: theme.colorScheme.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 4.r),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

