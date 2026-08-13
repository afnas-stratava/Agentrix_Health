import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/prescriptions/prescription.dart';
import '../../domain/repositories/prescription_repository.dart';

/// Prescription history, on the device. Mirrors `PrefsLabRepository` — same
/// on-device-only design for the same reason: this is health data as
/// sensitive as a lab result, and it does not leave the phone in this build.
class PrefsPrescriptionRepository implements PrescriptionRepository {
  PrefsPrescriptionRepository();

  static const _key = 'prescriptions.v1';

  @override
  Future<List<Prescription>> loadPrescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((p) => Prescription.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    } catch (error) {
      debugPrint('Discarding unreadable prescription history: $error');
      return [];
    }
  }

  @override
  Future<void> savePrescriptions(List<Prescription> prescriptions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(prescriptions.map((p) => p.toJson()).toList()),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class InMemoryPrescriptionRepository implements PrescriptionRepository {
  InMemoryPrescriptionRepository({List<Prescription>? prescriptions})
    : _prescriptions = [...?prescriptions];

  List<Prescription> _prescriptions;

  @override
  Future<List<Prescription>> loadPrescriptions() async => [..._prescriptions];

  @override
  Future<void> savePrescriptions(List<Prescription> prescriptions) async =>
      _prescriptions = [...prescriptions];

  @override
  Future<void> clear() async => _prescriptions = [];
}
