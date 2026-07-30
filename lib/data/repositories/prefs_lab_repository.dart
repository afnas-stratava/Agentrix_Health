import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/labs/lab_report.dart';
import '../../domain/repositories/lab_repository.dart';

/// Blood-test history, on the device.
///
/// Health data of this sensitivity does not leave the phone in this build: there
/// is no upload, and the Firestore document holds only the declared profile. If
/// syncing is added later it belongs behind a real account, not the anonymous
/// uid the app currently signs in with.
class PrefsLabRepository implements LabRepository {
  PrefsLabRepository();

  static const _key = 'lab_reports.v1';

  @override
  Future<List<LabReport>> loadReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((r) => LabReport.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (error) {
      debugPrint('Discarding unreadable lab history: $error');
      return [];
    }
  }

  @override
  Future<void> saveReports(List<LabReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(reports.map((r) => r.toJson()).toList()),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class InMemoryLabRepository implements LabRepository {
  InMemoryLabRepository({List<LabReport>? reports}) : _reports = [...?reports];

  List<LabReport> _reports;

  @override
  Future<List<LabReport>> loadReports() async => [..._reports];

  @override
  Future<void> saveReports(List<LabReport> reports) async =>
      _reports = [...reports];

  @override
  Future<void> clear() async => _reports = [];
}
