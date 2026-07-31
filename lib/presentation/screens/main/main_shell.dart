import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../providers/main_tab_provider.dart';
import 'food_log_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'labs_screen.dart';
import 'log_meal_screen.dart';
import 'profile_screen.dart';

/// Mirrors `app/(tabs)/_layout.tsx` + `PillTabBar`.
///
/// The dark title bar is gone: in the React Native app no tab has a chrome
/// header — each screen opens with its own copy, and the bar floats over the
/// content instead of boxing it in. Every screen therefore sits on the same
/// washed canvas from top to bottom.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  /// Space the floating bar needs at the bottom of a scroll view.
  static const double contentBottomInset = 130;

  /// Bottom padding for a scrolling screen, whichever way it was reached.
  ///
  /// A pushed route covers the tab bar, so reserving [contentBottomInset] there
  /// leaves a dead band of empty canvas at the end of the scroll. The same
  /// screen shown as a tab does need it.
  static double bottomInsetFor(BuildContext context) =>
      Navigator.canPop(context) ? AppSpacing.space8 : contentBottomInset;

  /// Opens a full-screen route over the shell, as the React Native app's stack
  /// routes do — the tab bar is covered and the screen can be backed out of.
  ///
  /// Supplies the chrome the tab shell would otherwise provide: the washed
  /// canvas, the status-bar style, a top safe area, and a back affordance. The
  /// pushed screens are built as tab content and have none of their own, so
  /// without this they render on bare background with no way back but a swipe.
  static Future<void> push(BuildContext context, Widget screen) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _PushedRoute(child: screen)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(mainTabProvider);

    return StatusBarStyle(
      light: false,
      // Plain canvas: only Today carries the gradient wash, and it applies it
      // itself.
      child: ColoredBox(
        color: AppColors.canvas,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              // Order must match `MainTab`'s declaration order — IndexedStack
              // selects by index, so a mismatch silently shows the wrong screen.
              child: IndexedStack(
                index: activeTab.index,
                children: const [
                  HomeScreen(),
                  FoodLogScreen(),
                  InsightsScreen(),
                  LabsScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
            const Align(alignment: Alignment.bottomCenter, child: _PillTabBar()),
          ],
        ),
      ),
    );
  }
}

/// Chrome for a screen reached by [MainShell.push].
///
/// Supplies only what the tab shell would have: the washed canvas, the
/// status-bar style and a top safe area. The back affordance is *not* here —
/// each pushed screen places a [ScreenBackButton] inline in its own heading row,
/// which reads better than a title bar repeating a heading the screen already
/// shows, and which collapses to nothing when the same screen is shown as a tab.
class _PushedRoute extends StatelessWidget {
  const _PushedRoute({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StatusBarStyle(
      light: false,
      child: ColoredBox(
        color: AppColors.canvas,
        // A pushed route builds outside the shell's own Material, and without
        // one in scope `WidgetsApp` falls back to its error text style — every
        // heading and paragraph on Upload, Gmail import, the metric detail and
        // the rest rendered yellow and underlined, and ink ripples had no
        // surface to paint on. Transparency keeps the canvas behind it.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(bottom: false, child: child),
        ),
      ),
    );
  }
}

/// Floating bar with a centre action button, from `PillTabBar`.
///
/// The same four routes the React Native `ICONS` map names, in the same order,
/// split either side of the centre action. `settings` is a route but gets no
/// slot — five icons plus the action button reads as cramped, and it is always
/// one tap from the Today header.
///
/// Everything not in this list is a pushed route, reached from the feed: the
/// brief from the top card, dining and the cycle tracker from their cards.
class _PillTabBar extends ConsumerWidget {
  const _PillTabBar();

  static const _items = [
    (tab: MainTab.today, icon: Icons.home_outlined, label: 'Today'),
    (tab: MainTab.food, icon: Icons.restaurant_outlined, label: 'Food'),
    (tab: MainTab.insights, icon: Icons.insights_outlined, label: 'Insights'),
    (tab: MainTab.labs, icon: Icons.science_outlined, label: 'Labs'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(mainTabProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Widget slot(({MainTab tab, IconData icon, String label}) item) => Expanded(
      child: _TabSlot(
        icon: item.icon,
        label: item.label,
        active: activeTab == item.tab,
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(mainTabProvider.notifier).select(item.tab);
        },
      ),
    );

    return Padding(
      // Insets and height from the design reference's tab-bar spec: 16px
      // gutters, 15px off the bottom, 66px tall.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
        bottomInset > 0 ? bottomInset : 15,
      ),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          // `rounded-pill`, per the shape table — the bar is in the same
          // family as buttons, badges and toggles, not the card family.
          borderRadius: BorderRadius.circular(AppRadius.pill),
          // A soft lift rather than an outline — the light theme reads as
          // floating cards, so a hard border here would fight everything else.
          boxShadow: const [
            BoxShadow(
              color: Color(0x2913281C), // rgba(19,40,28,.16)
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            slot(_items[0]),
            slot(_items[1]),
            const _CentreAction(),
            slot(_items[2]),
            slot(_items[3]),
          ],
        ),
      ),
    );
  }
}

/// The several-times-a-day action, punched out of the bar by a surface-coloured
/// ring. Logging a meal is that action here; uploading blood work is monthly
/// and stays inside its own tab.
class _CentreAction extends ConsumerWidget {
  const _CentreAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 62,
      // Lifted out of the bar's bounds, as in `PillTabBar`'s `top: -20`.
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: Semantics(
          button: true,
          label: 'Log a meal',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              // Opens the logging sheet directly rather than routing to the Food
              // tab — the several-times-a-day action should cost one tap, not two.
              MainShell.push(context, const LogMealScreen());
            },
            child: Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
                // The ring is canvas-white rather than pure surface, which is
                // what makes the button read as punched through the bar.
                border: Border.all(color: const Color(0xFFF7FBF3), width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80A6D934),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 27, color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// The focused tab reveals its label; the others stay icon-only. That keeps the
/// bar quiet while still naming where you are.
class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.space2),
              decoration: BoxDecoration(
                color: active ? AppColors.brand50 : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 25,
                color: active ? AppColors.brand600 : AppColors.faint,
              ),
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.tag.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.brand600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
