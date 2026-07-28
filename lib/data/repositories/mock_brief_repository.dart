import '../../domain/entities/brief_line.dart';
import '../../domain/repositories/brief_repository.dart';

class MockBriefRepository implements BriefRepository {
  @override
  List<List<BriefLine>> briefVariants() {
    return const [
      [
        BriefLine(
          tag: 'Iron',
          text:
              "Your iron is a little low — work in spinach, lentils or red meat today.",
        ),
        BriefLine(
          tag: 'Sleep',
          text: "You slept 6.5 hrs — let's aim for 7.5 tonight.",
        ),
        BriefLine(tag: 'Steps', text: 'Step target: 8,500 steps.'),
        BriefLine(tag: 'Burn', text: 'Calorie burn goal: 500 kcal.'),
        BriefLine(tag: 'Water', text: 'Water: 2.5L today.'),
        BriefLine(tag: 'Food', text: 'Ease off high-sugar foods today.'),
        BriefLine(
          tag: 'Energy',
          text: 'Energy level: high — good day for a workout.',
        ),
      ],
      [
        BriefLine(
          tag: 'Energy',
          text:
              "You're reading high-energy today — great window for a harder training session.",
        ),
        BriefLine(
          tag: 'Iron',
          text:
              "Iron's still trending low. A spinach salad or lentils at lunch will help.",
        ),
        BriefLine(
          tag: 'Sleep',
          text: '6.5 hrs last night — try winding down 45 min earlier tonight.',
        ),
        BriefLine(
          tag: 'Steps',
          text: '8,500 steps keeps you on pace for the week.',
        ),
        BriefLine(
          tag: 'Water',
          text: '2.5L water — sip steadily rather than all at once.',
        ),
        BriefLine(
          tag: 'Food',
          text: 'Watch added sugar today, especially in the afternoon.',
        ),
        BriefLine(tag: 'Burn', text: 'Burn goal: 500 kcal.'),
      ],
      [
        BriefLine(
          tag: 'Sleep',
          text:
              '6.5 hrs of sleep is a bit short for you — tonight, aim for lights out by 10:30.',
        ),
        BriefLine(
          tag: 'Iron',
          text:
              'Low iron again this week. Red meat, lentils or spinach today would help a lot.',
        ),
        BriefLine(
          tag: 'Food',
          text: "Sugar's crept up this week — keep today lighter on it.",
        ),
        BriefLine(
          tag: 'Steps',
          text: '8,500 steps and 500 kcal burned are within easy reach today.',
        ),
        BriefLine(tag: 'Water', text: '2.5L water today.'),
        BriefLine(
          tag: 'Energy',
          text: 'Energy: high. Good day to push yourself a bit.',
        ),
      ],
    ];
  }

  @override
  Future<void> simulateGeneration() =>
      Future.delayed(const Duration(milliseconds: 850));
}
