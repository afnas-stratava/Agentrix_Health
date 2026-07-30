import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/util/iso_day.dart';
import '../../domain/entities/nutrition/meal_entry.dart';
import '../../domain/repositories/meal_log_repository.dart';

/// The food log, on the device.
///
/// `SharedPreferences` rather than a database because the whole dataset is a few
/// kilobytes of JSON that is always read in full — a sqlite dependency would buy
/// query capability nothing here asks for. If the log ever grows past a few
/// months, this is the seam to swap.
///
/// Every read is defensive: a decode failure returns an empty log rather than
/// throwing, because a corrupt preference must not make the app unlaunchable.
class PrefsMealLogRepository implements MealLogRepository {
  PrefsMealLogRepository();

  static const _mealsKey = 'meal_log.v1';
  static const _hydrationKey = 'hydration.v1';

  @override
  Future<List<MealEntry>> loadMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mealsKey);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => MealEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (error) {
      debugPrint('Discarding unreadable meal log: $error');
      return [];
    }
  }

  @override
  Future<void> saveMeals(List<MealEntry> meals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _mealsKey,
      jsonEncode(meals.map((m) => m.toJson()).toList()),
    );
  }

  @override
  Future<Map<IsoDay, int>> loadHydration() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hydrationKey);
    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key as IsoDay: (entry.value as num).round(),
      };
    } catch (error) {
      debugPrint('Discarding unreadable hydration log: $error');
      return {};
    }
  }

  @override
  Future<void> saveHydration(Map<IsoDay, int> hydration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hydrationKey, jsonEncode(hydration));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mealsKey);
    await prefs.remove(_hydrationKey);
  }
}

/// Used in tests and by the widget-test harness, where no platform channel for
/// `SharedPreferences` exists.
class InMemoryMealLogRepository implements MealLogRepository {
  InMemoryMealLogRepository({
    List<MealEntry>? meals,
    Map<IsoDay, int>? hydration,
  }) : _meals = [...?meals],
       _hydration = {...?hydration};

  List<MealEntry> _meals;
  Map<IsoDay, int> _hydration;

  @override
  Future<List<MealEntry>> loadMeals() async => [..._meals];

  @override
  Future<void> saveMeals(List<MealEntry> meals) async => _meals = [...meals];

  @override
  Future<Map<IsoDay, int>> loadHydration() async => {..._hydration};

  @override
  Future<void> saveHydration(Map<IsoDay, int> hydration) async =>
      _hydration = {...hydration};

  @override
  Future<void> clear() async {
    _meals = [];
    _hydration = {};
  }
}
