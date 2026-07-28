import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_bar_style.dart';
import '../../providers/main_tab_provider.dart';
import 'cycle_wellness_screen.dart';
import 'food_log_screen.dart';
import 'home_screen.dart';
import 'morning_brief_screen.dart';
import 'profile_screen.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(mainTabProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return StatusBarStyle(
      light: true,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space3 + topInset,
              AppSpacing.space6,
              AppSpacing.space3,
            ),
            color: AppColors.accent900,
            child: Text(
              activeTab.title,
              style: AppTextStyles.h5.copyWith(
                color: AppColors.bg,
                fontSize: 18,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space6),
              child: IndexedStack(
                index: activeTab.index,
                children: const [
                  HomeScreen(),
                  FoodLogScreen(),
                  MorningBriefScreen(),
                  CycleWellnessScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
          ),
          const _TabBar(),
        ],
      ),
    );
  }
}

class _TabBar extends ConsumerWidget {
  const _TabBar();

  static const _items = [
    (tab: MainTab.home, icon: Icons.home_outlined, label: 'Home'),
    (tab: MainTab.log, icon: Icons.restaurant_outlined, label: 'Log'),
    (tab: MainTab.brief, icon: Icons.wb_sunny_outlined, label: 'Brief'),
    (tab: MainTab.cycle, icon: Icons.calendar_month_outlined, label: 'Cycle'),
    (tab: MainTab.profile, icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(mainTabProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space2,
        AppSpacing.space2,
        AppSpacing.space2,
        AppSpacing.space4 + bottomInset,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 2)),
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _TabBarItem(
                icon: item.icon,
                label: item.label,
                active: activeTab == item.tab,
                onTap: () =>
                    ref.read(mainTabProvider.notifier).select(item.tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({
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
    final color = active ? AppColors.accent700 : AppColors.neutral600;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: active ? AppColors.accent700 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(icon, size: 20, color: color),
            Text(
              label,
              style: AppTextStyles.cardMeta.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
