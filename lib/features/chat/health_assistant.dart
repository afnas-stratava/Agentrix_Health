import '../../domain/entities/health/metric_key.dart';
import '../../domain/entities/insights/readiness.dart';
import '../../domain/entities/labs/biomarker.dart';
import '../../domain/entities/labs/lab_report.dart';
import '../../domain/entities/nutrition/macros.dart';
import '../../domain/entities/nutrition/nutrition_targets.dart';
import '../../domain/entities/user_profile.dart';

/// Everything the assistant is allowed to read about the user, gathered up
/// front so [answerHealthQuestion] stays a pure function over the message and
/// a snapshot — no provider reads buried inside the reply logic.
class HealthAssistantContext {
  const HealthAssistantContext({
    required this.profile,
    required this.readiness,
    required this.consumedToday,
    required this.targets,
    required this.hydrationCupsToday,
    required this.latestLabReport,
  });

  final UserProfile profile;
  final Readiness? readiness;
  final Macros consumedToday;
  final NutritionTargets? targets;
  final int hydrationCupsToday;
  final LabReport? latestLabReport;
}

/// Grounds a hosted model in the same facts [answerHealthQuestion] reads —
/// the Gemini system prompt built for [ChatNotifier]'s primary path. Kept
/// alongside the rule-based engine so the two paths can never drift into
/// citing different numbers for the same user.
String buildHealthAssistantSystemPrompt(HealthAssistantContext context) {
  final profile = context.profile;
  final lines = <String>[
    'You are "Health Assistant", the built-in chat assistant inside a '
        "personal health-tracking app. Tone: warm and concise — 2 to 4 "
        'sentences unless the user asks for more detail. Speak directly to '
        'them, using their first name when it reads naturally.',
    'You are not a clinician. Never diagnose a condition or claim to know '
        'what a result "means" medically. If a number looks concerning, say '
        'so plainly and suggest they take it to a clinician, rather than '
        'interpreting it yourself.',
    'Stay strictly on health and wellness: sleep, readiness, food and '
        'nutrition, hydration, activity and exercise, lab results and '
        'biomarkers, weight, and wellbeing (stress, mood, energy) as it '
        'relates to their health. If the user asks for anything outside that '
        '— coding, homework, general trivia, current events, entertainment, '
        'writing tasks, or anything unrelated to their health — do not '
        'answer it, even if you know the answer. Decline briefly and steer '
        'back, e.g. "I\'m just here for health and wellness — anything '
        'about your sleep, food, or labs I can help with?"',
    'Only reference the facts listed below — this is the entire real data '
        'set you have about this user. Never invent a metric, biomarker '
        'value, meal, or date that is not given here.',
    '',
    'User profile:',
    '- Name: ${profile.name.trim().isEmpty ? 'not set' : profile.name}',
    '- Goals: ${profile.goals.map((g) => '${g.label} (${g.hint})').join('; ')}',
    '- Activity level: ${profile.activityLevel.label}',
  ];

  final readiness = context.readiness;
  if (readiness != null) {
    final copy = readinessCopy[readiness.band]!;
    lines.add(
      '- Readiness today: ${readiness.score}/100, ${copy.label} '
      '(${copy.blurb})',
    );
    if (readiness.drivers.isNotEmpty) {
      final top = readiness.drivers.reduce(
        (a, b) => a.contribution.abs() > b.contribution.abs() ? a : b,
      );
      final label = metricMeta[top.metric]?.label ?? top.metric.name;
      final direction = top.contribution >= 0 ? 'helping most' : 'hurting most';
      lines.add('  Top driver vs. baseline: $label ($direction)');
    }
  } else {
    lines.add('- Readiness: not enough telemetry yet today');
  }

  final consumed = context.consumedToday;
  final targets = context.targets;
  if (targets != null) {
    lines.add(
      '- Food today: ${consumed.calories}/${targets.calories} kcal, '
      '${consumed.proteinG.round()}/${targets.macros.proteinG}g protein',
    );
  } else {
    lines.add(
      '- Food today: ${consumed.calories} kcal logged, '
      '${consumed.proteinG.round()}g protein (no targets configured yet)',
    );
  }

  lines.add(
    '- Hydration today: ${context.hydrationCupsToday} cups logged '
    '(rough target: 8)',
  );

  final report = context.latestLabReport;
  if (report == null) {
    lines.add('- Labs: no report on file');
  } else {
    final flagged = report.biomarkers
        .where(
          (b) =>
              b.flag != BiomarkerFlag.normal && b.flag != BiomarkerFlag.optimal,
        )
        .toList();
    if (flagged.isEmpty) {
      lines.add(
        '- Labs: latest panel'
        '${report.labName != null ? ' (${report.labName})' : ''} — '
        'everything in range',
      );
    } else {
      final items = flagged
          .map(
            (b) =>
                '${b.displayName} ${b.valueLabel}${b.unit} (${b.flag.label})',
          )
          .join(', ');
      lines.add('- Labs: latest panel flagged — $items');
    }
  }

  return lines.join('\n');
}

/// Keyword-routed health assistant. Not a call to a hosted model — like the
/// meal-suggestion and correlation engines elsewhere in `features/`, it is a
/// deterministic engine over the user's own data, so a reply never depends on
/// network availability and never cites a fact this app cannot back with a
/// real number. Every branch answers from [HealthAssistantContext]; nothing
/// here invents a value it wasn't given.
String answerHealthQuestion(String message, HealthAssistantContext context) {
  final text = message.trim().toLowerCase();
  if (text.isEmpty) return _fallback(context);

  bool has(List<String> words) => words.any(text.contains);

  if (has(['hello', 'hi', 'hey', 'yo ', 'sup'])) return _greeting(context);
  if (has(['thank', 'thanks', 'thx'])) {
    return "You're welcome — I'm here whenever you want to check in.";
  }
  if (has(['who are you', 'what can you', 'what do you do', 'help'])) {
    return _capabilities();
  }
  if (has([
    'sleep',
    'tired',
    'exhaust',
    'rest',
    'readiness',
    'recover',
    'hrv',
    'heart rate',
  ])) {
    return _readinessReply(context);
  }
  if (has([
    'eat',
    'food',
    'meal',
    'calorie',
    'protein',
    'carb',
    'fat',
    'diet',
    'nutrition',
    'hungry',
  ])) {
    return _nutritionReply(context);
  }
  if (has(['water', 'hydrat', 'drink'])) return _hydrationReply(context);
  if (has([
    'lab',
    'blood',
    'biomarker',
    'vitamin',
    'cholesterol',
    'glucose',
    'iron',
    'ferritin',
    'thyroid',
  ])) {
    return _labsReply(context);
  }
  if (has(['exercise', 'workout', 'train', 'gym', 'run', 'steps', 'active'])) {
    return _activityReply(context);
  }
  if (has(['stress', 'anxious', 'anxiety', 'mood', 'overwhelm'])) {
    return _stressReply();
  }
  if (has(['weight', 'goal'])) return _goalReply(context);

  return _fallback(context);
}

String _firstName(UserProfile profile) => profile.name.trim().isEmpty
    ? 'there'
    : profile.name.trim().split(' ').first;

String _greeting(HealthAssistantContext context) {
  final name = _firstName(context.profile);
  final readiness = context.readiness;
  if (readiness == null) {
    return "Hey $name! I'm your health assistant — ask me about your sleep, "
        "meals, hydration or labs any time.";
  }
  final band = readinessCopy[readiness.band]!.label.toLowerCase();
  return 'Hey $name! Your readiness is reading $band today '
      '(${readiness.score}/100). What would you like to check in on — '
      'food, sleep, hydration or your last labs?';
}

String _capabilities() {
  return "I can talk through what's already in your app: today's readiness "
      "and sleep, how your meals stack up against your targets, hydration, "
      "and any flagged results from your last lab report. Try asking "
      '"how did I sleep" or "how much protein have I had today".';
}

String _readinessReply(HealthAssistantContext context) {
  final readiness = context.readiness;
  if (readiness == null) {
    return "I don't have enough telemetry yet to score your readiness — "
        'keep wearing your tracker and check back tomorrow.';
  }
  final copy = readinessCopy[readiness.band]!;
  final buffer = StringBuffer(
    'Readiness is ${readiness.score}/100 today — ${copy.label.toLowerCase()}. '
    '${copy.blurb}',
  );
  if (readiness.drivers.isNotEmpty) {
    final top = readiness.drivers.reduce(
      (a, b) => a.contribution.abs() > b.contribution.abs() ? a : b,
    );
    final label = metricMeta[top.metric]?.label ?? top.metric.name;
    final direction = top.contribution >= 0 ? 'is helping most' : 'is dragging it down most';
    buffer.write(' $label $direction versus your baseline.');
  }
  return buffer.toString();
}

String _nutritionReply(HealthAssistantContext context) {
  final consumed = context.consumedToday;
  final targets = context.targets;
  if (targets == null) {
    return "You've logged ${consumed.calories} kcal today "
        '(${consumed.proteinG.round()}g protein). Set up your profile targets '
        'from the Profile tab and I can tell you how that compares.';
  }
  final calorieDelta = targets.calories - consumed.calories;
  final proteinDelta = targets.macros.proteinG - consumed.proteinG;
  final calorieLine = calorieDelta > 0
      ? '${calorieDelta.round()} kcal left for the day'
      : '${(-calorieDelta).round()} kcal over your target';
  final proteinLine = proteinDelta > 0
      ? '${proteinDelta.round()}g of protein still to go'
      : 'protein target already met';
  return "So far today: ${consumed.calories} kcal of ${targets.calories} — "
      '$calorieLine. ${consumed.proteinG.round()}g protein of '
      '${targets.macros.proteinG}g — $proteinLine.';
}

String _hydrationReply(HealthAssistantContext context) {
  const goalCups = 8;
  final cups = context.hydrationCupsToday;
  if (cups >= goalCups) {
    return "You're at $cups cups today — nicely past the $goalCups-cup mark. "
        'Keep sipping through the afternoon if it is warm out.';
  }
  final remaining = goalCups - cups;
  return "You've logged $cups of about $goalCups cups today — "
      '$remaining to go. A glass with each meal gets you there without thinking about it.';
}

String _labsReply(HealthAssistantContext context) {
  final report = context.latestLabReport;
  if (report == null) {
    return "You don't have a lab report on file yet — upload one from the "
        'Labs tab and I can flag anything outside range.';
  }
  final flagged = report.biomarkers
      .where(
        (b) => b.flag != BiomarkerFlag.normal && b.flag != BiomarkerFlag.optimal,
      )
      .toList();
  if (flagged.isEmpty) {
    return 'Your most recent panel${report.labName != null ? ' from ${report.labName}' : ''} '
        "came back clean — everything I can read is within range.";
  }
  final names = flagged.take(3).map((b) => '${b.displayName} (${b.flag.label.toLowerCase()})');
  final more = flagged.length > 3 ? ', and ${flagged.length - 3} more' : '';
  return 'From your latest panel, keep an eye on: ${names.join(', ')}$more. '
      'Tap into the Labs tab for the reference ranges and what each one means.';
}

String _activityReply(HealthAssistantContext context) {
  final readiness = context.readiness;
  final level = context.profile.activityLevel.label;
  if (readiness == null) {
    return "I don't have today's activity telemetry yet, but your declared "
        "activity level is set to $level.";
  }
  final band = readiness.band;
  if (band == ReadinessBand.compromised || band == ReadinessBand.low) {
    return 'Readiness is ${readiness.score}/100 today, so this reads as a good '
        'day to keep training light — a walk or mobility work rather than a hard session.';
  }
  return 'Readiness is ${readiness.score}/100 — your body looks ready for a normal '
      'or harder session today if that fits your plan.';
}

String _stressReply() {
  return "That's worth paying attention to. A short walk, slower breathing for "
      "a few minutes, or a earlier wind-down tonight can all move the needle. "
      "If it's persistent, your sleep and readiness trends in this app are worth "
      'a look with a clinician.';
}

String _goalReply(HealthAssistantContext context) {
  final goal = context.profile.goal;
  final weightKg = context.profile.weightKg;
  final targetKg = context.profile.targetWeightKg;
  final buffer = StringBuffer('Your current goal is set to "${goal.label}" — ${goal.hint.toLowerCase()}.');
  if (weightKg != null && targetKg != null) {
    final delta = weightKg - targetKg;
    if (delta.abs() >= 0.5) {
      buffer.write(
        ' You are logged at ${weightKg.toStringAsFixed(1)}kg against a '
        '${targetKg.toStringAsFixed(1)}kg target.',
      );
    }
  }
  return buffer.toString();
}

String _fallback(HealthAssistantContext context) {
  final name = _firstName(context.profile);
  return "I'm not sure I follow, $name. I can help with sleep and readiness, "
      "today's food log, hydration, your labs, or activity — try asking about one of those.";
}
