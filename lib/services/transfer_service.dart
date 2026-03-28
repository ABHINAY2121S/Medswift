import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer.dart';
import 'auth_service.dart';

class TransferService {
  static final _db = FirebaseFirestore.instance;
  static final _uuid = const Uuid();

  // ── Drug-Allergy conflict map ──────────────────────────────────────────────
  static final Map<String, List<String>> _drugAllergyConflicts = {
    'penicillin': ['amoxicillin', 'ampicillin', 'piperacillin', 'penicillin'],
    'sulfa': ['sulfamethoxazole', 'trimethoprim', 'bactrim', 'sulfa'],
    'aspirin': ['nsaid', 'ibuprofen', 'naproxen', 'diclofenac', 'aspirin'],
    'codeine': ['codeine', 'morphine', 'opioid', 'tramadol'],
    'latex': ['latex'],
    'contrast': ['contrast dye', 'iodine', 'gadolinium'],
    'cephalosporin': ['cephalexin', 'cefazolin', 'ceftriaxone'],
  };

  /// Returns list of conflict warnings
  static List<String> detectConflicts(String allergies, String medications) {
    final allergyLower = allergies.toLowerCase();
    final medLower = medications.toLowerCase();
    final conflicts = <String>[];

    for (final allergen in _drugAllergyConflicts.keys) {
      if (allergyLower.contains(allergen)) {
        for (final drug in _drugAllergyConflicts[allergen]!) {
          if (medLower.contains(drug)) {
            conflicts.add('⚠ Patient is allergic to $allergen — $drug detected in medications!');
          }
        }
      }
    }
    return conflicts;
  }

  /// Suggests risk level based on vitals and diagnosis
  static String suggestRisk(Vitals v, String diagnosis) {
    int score = 0;

    final criticalDx = ['infarction', 'stroke', 'hemorrhage', 'polytrauma',
        'sepsis', 'cardiac arrest', 'respiratory failure', 'shock',
        'pulmonary embolism', 'aneurysm', 'coma'];
    final moderateDx = ['fracture', 'pneumonia', 'appendicitis', 'diabetic',
        'hypertensive', 'angina', 'arrhythmia', 'altered consciousness'];
    final diagLower = diagnosis.toLowerCase();
    for (final dx in criticalDx) {
      if (diagLower.contains(dx)) { score = 2; break; }
    }
    if (score < 2) {
      for (final dx in moderateDx) {
        if (diagLower.contains(dx)) { score = score < 1 ? 1 : score; break; }
      }
    }

    if (v.pulse.isNotEmpty) {
      final hr = int.tryParse(v.pulse.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (hr > 0) {
        if (hr < 40 || hr > 130) score = 2;
        else if ((hr < 60 || hr > 100) && score < 2) score = score < 1 ? 1 : score;
      }
    }

    if (v.bp.contains('/')) {
      final parts = v.bp.split('/');
      final sys = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 120;
      final dia = parts.length > 1
          ? (int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 80)
          : 80;
      if (sys < 80 || sys > 180 || dia > 120) score = 2;
      else if ((sys < 90 || sys > 160 || dia > 100) && score < 2) score = score < 1 ? 1 : score;
    }

    if (v.spo2.isNotEmpty) {
      final spo2 = int.tryParse(v.spo2.replaceAll(RegExp(r'[^0-9]'), '')) ?? 100;
      if (spo2 < 90) score = 2;
      else if (spo2 < 95 && score < 2) score = score < 1 ? 1 : score;
    }

    if (v.temp.isNotEmpty) {
      final tempStr = v.temp.replaceAll(RegExp(r'[^0-9.]'), '');
      final temp = double.tryParse(tempStr) ?? 98.6;
      final tempF = temp < 45 ? (temp * 9 / 5) + 32 : temp;
      if (tempF < 95.0 || tempF > 104.0) score = 2;
      else if (tempF > 100.4 && score < 2) score = score < 1 ? 1 : score;
    }

    if (score >= 2) return 'critical';
    if (score == 1) return 'moderate';
    return 'safe';
  }

  // ── CRUD (Firestore-backed) ───────────────────────────────────────────────

  /// Get all transfers (for doctor dashboard — all transfers in system)
  static Future<List<PatientTransfer>> getAll() async {
    try {
      final snap = await _db
          .collection('transfers')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => PatientTransfer.fromJson(d.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get transfers for a specific patient by their phone number
  static Future<List<PatientTransfer>> getPatientTransfers(String patientPhone) async {
    if (patientPhone.isEmpty) return [];
    try {
      final normPhone = AuthService.normalizePhone(patientPhone);
      // NOTE: We intentionally do NOT use .orderBy() together with .where()
      // because that requires a Firestore composite index.
      // We sort client-side instead — works without any Firebase Console setup.
      final snap = await _db
          .collection('transfers')
          .where('patientPhone', isEqualTo: normPhone)
          .get();
      final list = snap.docs
          .map((d) => PatientTransfer.fromJson(d.data()))
          .toList();
      // Sort newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      // ignore: avoid_print
      print('[TransferService.getPatientTransfers] ERROR: $e');
      return [];
    }
  }

  /// Save (create or update) a transfer in Firestore
  static Future<void> save(PatientTransfer t) async {
    await _db.collection('transfers').doc(t.id).set(t.toJson());
  }

  static Future<void> delete(String id) async {
    await _db.collection('transfers').doc(id).delete();
  }

  static Future<PatientTransfer?> getById(String id) async {
    try {
      final snap = await _db.collection('transfers').doc(id).get();
      if (!snap.exists) return null;
      return PatientTransfer.fromJson(snap.data()!);
    } catch (_) {
      return null;
    }
  }

  static String generateId() => _uuid.v4().substring(0, 8).toUpperCase();

  static String generatePatientId() =>
      'MR-${DateTime.now().year}-${_uuid.v4().substring(0, 4).toUpperCase()}';
}
