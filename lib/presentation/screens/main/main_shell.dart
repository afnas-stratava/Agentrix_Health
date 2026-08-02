import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../providers/main_tab_provider.dart';
import '../../widgets/canvas_wash.dart';
import 'ai_chat_screen.dart';
import 'food_log_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'labs_screen.dart';
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

    final content = Stack(
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
    );

    // Only Today carries the gradient wash — but it is painted *here*, outside
    // the safe area, so it runs behind the status bar. Applied inside the screen
    // it started below the notch, and the seam where flat canvas met the top of
    // the gradient read as two different greens.
    return StatusBarStyle(
      light: false,
      child: activeTab == MainTab.today
          ? CanvasWash(child: content)
          : ColoredBox(color: AppColors.canvas, child: content),
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

  /// `h-[72px]` on the RN bar. Shared with [_TabSlot], which needs the full
  /// inner height to centre an icon against it — the bar has no vertical
  /// padding, so the two are the same number.
  static const double barHeight = 72;

  /// `rounded-[28px]`. Deliberately *not* [AppRadius.pill]: at 72 tall a pill
  /// would round to 36 and read as a capsule, where the reference is a rounded
  /// rectangle.
  static const double barRadius = 28;

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
      // `px-5`, `paddingTop: 8`, `paddingBottom: Math.max(insets.bottom, 14)`
      // from `PillTabBar`. The floor matters: a device reporting a 1–13pt
      // bottom inset would otherwise sit the bar almost on the screen edge.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space2,
        AppSpacing.space5,
        bottomInset > 14 ? bottomInset : 14,
      ),
      child: Container(
        height: barHeight,
        // `px-2`. This was 14, which squeezed the four slots inward and left
        // the gaps either side of the centre action visibly tighter than the
        // gaps between neighbouring tabs.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(barRadius),
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
        // Ink needs a Material at or above it to paint on. The nearest one was
        // the root in `app.dart`, *below* this bar's opaque white fill, so every
        // tap ripple was painted underneath the bar and never seen — selecting a
        // tab felt inert. A transparent Material here puts the ripple on top of
        // the pill. It deliberately does not clip: the centre action is lifted
        // above the bar's bounds and clipping would slice its top off.
        child: Material(
          type: MaterialType.transparency,
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
      ),
    );
  }
}

/// The several-times-a-day action, punched out of the bar by a surface-coloured
/// ring. Talking to the health assistant is that action here; logging a meal
/// and uploading blood work stay one tap away from the Food and Labs tabs
/// instead of sharing this slot.
class _CentreAction extends StatefulWidget {
  const _CentreAction();

  @override
  State<_CentreAction> createState() => _CentreActionState();
}

/// Two separate motions, for two different jobs.
///
/// The **breath** runs a fixed number of times when the bar first appears and
/// then stops for good. It is what makes the assistant read as something you
/// can talk to rather than a fifth tab. It is deliberately finite: a button
/// that pulses forever becomes wallpaper within a minute and noise after that,
/// and an endlessly repeating controller would also hang every widget test
/// that calls `pumpAndSettle`, which never returns while a frame is scheduled.
///
/// The **press** is ordinary tactile feedback and runs whenever touched.
///
/// Both are `Transform`s wrapping the button, so neither changes the 62x62 box
/// this widget occupies — the bar's spacing and the lifted-clear-of-the-bar
/// geometry are unaffected.
class _CentreActionState extends State<_CentreAction>
    with SingleTickerProviderStateMixin {
  /// Three rises and falls, slow enough to read as breathing rather than
  /// blinking.
  static const int _breaths = 3;
  static const Duration _breathPeriod = Duration(milliseconds: 1500);

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: _breathPeriod * _breaths,
  );

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Deferred a frame so the entrance animation is not competing with the
    // shell's own first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Honours the system "Reduce Motion" setting. Someone who has asked for
      // less movement should not get an attention-seeking button.
      if (MediaQuery.disableAnimationsOf(context)) return;
      _breath.forward();
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `fabWrapper` is 62x62 in RN. The height was missing here, so the box took
    // its height from the button inside it — which is why the button had grown
    // to fill the wrapper (62 across a 54px lime face) instead of sitting as a
    // 56px button with 3px of slack, and read oversized against the bar.
    return SizedBox(
      width: 62,
      height: 62,
      // Lifted out of the bar's bounds, as in `PillTabBar`'s `top: -20`.
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Center(
          child: Semantics(
            button: true,
            label: 'Ask the health assistant',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                MainShell.push(context, const AiChatScreen());
              },
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.92 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: AnimatedBuilder(
                  animation: _breath,
                  builder: (context, child) {
                    // A cosine over the whole run gives `_breaths` complete
                    // rises and falls that begin and end at rest, so the
                    // animation stopping is not a visible snap.
                    final wave =
                        (1 -
                            math.cos(
                              _breath.value * 2 * math.pi * _breaths,
                            )) /
                        2;
                    return Transform.scale(
                      scale: 1 + 0.045 * wave,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              // The lime glow swells with the breath. This is
                              // the part that carries the motion; the scale
                              // alone reads as a wobble.
                              color: const Color(
                                0xFFA6D934,
                              ).withValues(alpha: 0.5 + 0.35 * wave),
                              blurRadius: 14 + 14 * wave,
                              spreadRadius: 2 * wave,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  // Built once and reused across every frame — the face of the
                  // button never changes, only the glow and scale around it.
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                      // The ring is canvas-white rather than pure surface,
                      // which is what makes the button read as punched through
                      // the bar.
                      border: Border.all(
                        color: const Color(0xFFF7FBF3),
                        width: 5,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 22,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
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

  static const Duration _transition = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      // The inactive labels are laid out but invisible; without this a screen
      // reader would announce all four of them on top of the slot's own label.
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          // A Stack, not a Column.
          //
          // As a Column the icon and the label were one centred block, so the
          // icon sat half the label's height above the bar's middle — 7.5px
          // high, with a dead band of white underneath the three tabs whose
          // labels are invisible. Centring the icon and *hanging* the label off
          // the bottom edge keeps all four icons on the bar's centre line and
          // still lets the label fade in without moving anything.
          child: SizedBox(
            height: _PillTabBar.barHeight,
            child: Stack(
              children: [
                // The brand-50 disc this used to sit on was #EFF8F1 against a
                // white bar — barely a percent of contrast, so it read as a
                // smudge rather than a highlight. Colour and the label carry
                // the selected state instead, per the reference's `.tab.on`.
                Center(
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      end: active ? AppColors.brand600 : AppColors.faint,
                    ),
                    duration: _transition,
                    curve: Curves.easeOut,
                    builder: (context, value, _) =>
                        Icon(icon, size: 25, color: value ?? AppColors.faint),
                  ),
                ),
                // Always laid out, only faded — `opacity:0` / `.tab.on span
                // {opacity:1}` in the reference. Positioned rather than flowed,
                // so a long label cannot reflow the slot either.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 7,
                  child: AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: _transition,
                    curve: Curves.easeOut,
                    child: SizedBox(
                      height: 12,
                      // Scales down rather than ellipsising, so a long label
                      // still reads in full on a narrow phone.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          softWrap: false,
                          style: AppTextStyles.tag.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.brand600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
