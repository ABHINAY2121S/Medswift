import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer.dart';
import 'auth_service.dart';

class TransferService {
  static final _db = FirebaseFirestore.instance;
  static final _uuid = const Uuid();

  // ── Diagnosis keyword lists for risk scoring ─────────────────────────────
  static const _criticalDx = [
    'infarction', 'mi', 'stemi', 'nstemi', 'stroke', 'cva', 'tia',
    'hemorrhage', 'bleeding', 'polytrauma', 'sepsis', 'septicemia',
    'cardiac arrest', 'respiratory failure', 'ards', 'shock',
    'anaphylaxis', 'pulmonary embolism', 'pe', 'aortic aneurysm',
    'coma', 'status epilepticus', 'dka', 'hhs', 'hyperosmolar',
    'thyroid storm', 'thyrotoxic crisis', 'myxedema coma',
    'hypoglycemic coma', 'addisonian crisis',
  ];
  static const _moderateDx = [
    'fracture', 'pneumonia', 'appendicitis',
    'hypertensive urgency', 'angina', 'unstable angina', 'arrhythmia',
    'altered consciousness', 'syncope', 'uti', 'acute kidney injury',
    'aki', 'hyperglycemia', 'hypoglycemia', 'hypothyroidism',
    'hyperthyroidism', 'thyroiditis', 'atrial fibrillation',
    'dvt', 'pulmonary', 'pleuritis', 'pancreatitis', 'cholecystitis',
    'decompensated', 'exacerbation', 'copd exacerbation', 'asthma attack',
  ];

  // ── Drug-Allergy conflict map ──────────────────────────────────────────────
  static final Map<String, List<String>> _drugAllergyConflicts = {
    'penicillin':    ['amoxicillin', 'ampicillin', 'piperacillin', 'penicillin'],
    'sulfa':         ['sulfamethoxazole', 'trimethoprim', 'bactrim', 'sulfa'],
    'aspirin':       ['nsaid', 'ibuprofen', 'naproxen', 'diclofenac', 'aspirin', 'celecoxib'],
    'codeine':       ['codeine', 'morphine', 'opioid', 'tramadol', 'fentanyl', 'oxycodone'],
    'latex':         ['latex'],
    'contrast':      ['contrast dye', 'iodine', 'gadolinium', 'amiodarone'],
    'cephalosporin': ['cephalexin', 'cefazolin', 'ceftriaxone', 'cefuroxime'],
    'metformin':     ['metformin'],          // renal risk
    'insulin':       ['insulin', 'glipizide', 'glibenclamide', 'glyburide'],
    'levothyroxine': ['levothyroxine', 'thyroxine', 'synthroid'],
    'methimazole':   ['methimazole', 'carbimazole', 'propylthiouracil', 'ptu'],
    'ace inhibitor': ['lisinopril', 'enalapril', 'ramipril', 'captopril', 'perindopril'],
    'warfarin':      ['warfarin', 'coumadin', 'acenocoumarol'],
    'heparin':       ['heparin', 'enoxaparin', 'dalteparin', 'fondaparinux'],
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

  // ══════════════════════════════════════════════════════════════════════════
  //  ADVANCED RISK ENGINE  v2.0
  //  score × 10 = risk % (score 7 → 70%, score 10 → 100%)
  //  Categories: 0–39% = safe | 40–69% = moderate | 70–100% = critical
  // ══════════════════════════════════════════════════════════════════════════

  /// Shared scoring core used by both [suggestRisk] and [suggestRiskPercent].
  static int _computeRawScore(
    Vitals v,
    String diagnosis, {
    List<String> comorbidities = const [],
  }) {
    int score = 0;
    final diagLower = diagnosis.toLowerCase();

    // ── 1. DIAGNOSIS ───────────────────────────────────────────────────────
    for (final dx in _criticalDx) {
      if (diagLower.contains(dx)) { score += 5; break; }
    }
    if (score < 5) {
      for (final dx in _moderateDx) {
        if (diagLower.contains(dx)) { score += 3; break; }
      }
    }

    // ── 2. HEART RATE ──────────────────────────────────────────────────────
    if (v.pulse.isNotEmpty) {
      final hr = int.tryParse(v.pulse.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (hr > 0) {
        if (hr < 30 || hr > 150)       score += 5;
        else if (hr < 40 || hr > 130)  score += 4;
        else if (hr < 50 || hr > 110)  score += 2;
        else if (hr < 60 || hr > 100)  score += 1;
      }
    }

    // ── 3. BLOOD PRESSURE ──────────────────────────────────────────────────
    if (v.bp.contains('/')) {
      final parts = v.bp.split('/');
      final sys = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 120;
      final dia = parts.length > 1
          ? (int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 80)
          : 80;
      if (sys < 70 || sys > 200)       score += 5;
      else if (sys < 80 || sys > 180)  score += 4;
      else if (sys < 90 || sys > 160)  score += 2;
      else if (sys < 100 || sys > 140) score += 1;
      if (dia > 130)       score += 3;
      else if (dia > 110)  score += 2;
      else if (dia > 100)  score += 1;
    }

    // ── 4. SpO2 ────────────────────────────────────────────────────────────
    if (v.spo2.isNotEmpty) {
      final spo2 = int.tryParse(v.spo2.replaceAll(RegExp(r'[^0-9]'), '')) ?? 100;
      if (spo2 < 85)       score += 5;
      else if (spo2 < 90)  score += 4;
      else if (spo2 < 93)  score += 3;
      else if (spo2 < 95)  score += 1;
    }

    // ── 5. TEMPERATURE ─────────────────────────────────────────────────────
    if (v.temp.isNotEmpty) {
      final tempStr = v.temp.replaceAll(RegExp(r'[^0-9.]'), '');
      final temp = double.tryParse(tempStr) ?? 98.6;
      final tempF = temp < 45.0 ? (temp * 9 / 5) + 32 : temp;
      if (tempF < 93.0 || tempF > 106.0)       score += 5;
      else if (tempF < 95.0 || tempF > 104.0)  score += 3;
      else if (tempF > 101.0)                   score += 2;
      else if (tempF > 100.0)                   score += 1;
    }

    // ── 6. COMORBIDITIES ───────────────────────────────────────────────────
    final comorb = comorbidities.map((c) => c.toLowerCase()).toList();

    final hasDiabetes = comorb.any((c) =>
        c.contains('diabetes') || c.contains('diabetic') ||
        c.contains('type 1') || c.contains('type 2'));
    if (hasDiabetes) {
      score += 1;
      if (diagLower.contains('dka') || diagLower.contains('ketoacidosis') ||
          diagLower.contains('hyperosmolar') || diagLower.contains('hypoglycemi')) {
        score += 3;
      }
      if (v.bp.contains('/')) {
        final sys = int.tryParse(v.bp.split('/')[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 120;
        if (sys > 160) score += 1;
      }
    }

    final hasHypothyroid = comorb.any((c) =>
        c.contains('hypothyroid') || c.contains('hashimoto') || c.contains('myxedema'));
    final hasHyperthyroid = comorb.any((c) =>
        c.contains('hyperthyroid') || c.contains('graves') ||
        c.contains('thyroid storm') || c.contains('thyrotoxic'));

    if (hasHypothyroid) {
      score += 1;
      if (v.temp.isNotEmpty) {
        final t = double.tryParse(v.temp.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 98.6;
        final tF = t < 45 ? (t * 9 / 5) + 32 : t;
        if (tF < 96.0) score += 2;
      }
      if (v.pulse.isNotEmpty) {
        final hr = int.tryParse(v.pulse.replaceAll(RegExp(r'[^0-9]'), '')) ?? 70;
        if (hr < 50) score += 1;
      }
    }
    if (hasHyperthyroid) {
      score += 1;
      if (v.pulse.isNotEmpty) {
        final hr = int.tryParse(v.pulse.replaceAll(RegExp(r'[^0-9]'), '')) ?? 70;
        if (hr > 110) score += 2;
      }
      if (v.temp.isNotEmpty) {
        final t = double.tryParse(v.temp.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 98.6;
        final tF = t < 45 ? (t * 9 / 5) + 32 : t;
        if (tF > 101.0) score += 2;
      }
    }

    if (comorb.any((c) => c.contains('ckd') || c.contains('kidney') ||
        c.contains('renal') || c.contains('dialysis'))) {
      score += 1;
      if (diagLower.contains('hypertens') || diagLower.contains('ckd')) score += 1;
    }

    if (comorb.any((c) => c.contains('copd') || c.contains('emphysema') ||
        c.contains('asthma') || c.contains('pulmonary fibrosis'))) {
      score += 1;
      if (v.spo2.isNotEmpty) {
        final spo2 = int.tryParse(v.spo2.replaceAll(RegExp(r'[^0-9]'), '')) ?? 100;
        if (spo2 < 88) score += 2;
      }
    }

    if (comorb.any((c) => c.contains('cad') || c.contains('coronary') ||
        c.contains('heart failure') || c.contains('chf') || c.contains('hf'))) {
      score += 1;
      if (v.pulse.isNotEmpty) {
        final hr = int.tryParse(v.pulse.replaceAll(RegExp(r'[^0-9]'), '')) ?? 70;
        if (hr > 120 || hr < 45) score += 2;
      }
    }

    if (comorb.any((c) => c.contains('hypertension') || c.contains('htn'))) {
      score += 1;
    }

    if (comorb.any((c) => c.contains('immunocompromised') || c.contains('hiv') ||
        c.contains('transplant') || c.contains('chemotherapy') || c.contains('cancer'))) {
      score += 2;
    }

    return score;
  }

  /// Returns 'safe' | 'moderate' | 'critical'.
  static String suggestRisk(
    Vitals v,
    String diagnosis, {
    List<String> comorbidities = const [],
  }) {
    final pct = suggestRiskPercent(v, diagnosis, comorbidities: comorbidities);
    if (pct >= 70) return 'critical';
    if (pct >= 40) return 'moderate';
    return 'safe';
  }

  /// Returns a 0–100 risk percentage.
  /// score × 10, clamped to 100.
  /// 0–39% = safe | 40–69% = moderate | 70–100% = critical
  static int suggestRiskPercent(
    Vitals v,
    String diagnosis, {
    List<String> comorbidities = const [],
  }) {
    return (_computeRawScore(v, diagnosis, comorbidities: comorbidities) * 10)
        .clamp(0, 100);
  }

  // ── CRUD (Firestore-backed) ─────────────────────────────────────────────

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

  /// Save (create or update) a transfer in Firestore.
  /// Also auto-updates the sending doctor's stats.
  static Future<void> save(PatientTransfer t) async {
    final isNew = !(await _db.collection('transfers').doc(t.id).get()).exists;
    await _db.collection('transfers').doc(t.id).set(t.toJson());

    // Auto-track doctor stats — only if sendingDoctor has a phone-like id stored
    if (t.sendingDoctor.isNotEmpty) {
      if (isNew) {
        // New transfer → increment totalTransfers
        await AuthService.incrementDoctorStats(t.sendingDoctor, completed: false);
      } else if (t.status == 'received' || t.status == 'completed') {
        // Transfer arrived/completed → also increment completedTransfers
        await AuthService.incrementDoctorStats(t.sendingDoctor, completed: true);
      }
    }
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

  /// Real-time stream for a single transfer document
  static Stream<PatientTransfer?> stream(String id) {
    return _db.collection('transfers').doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return PatientTransfer.fromJson(snap.data()!);
    });
  }


  static String generateId() => _uuid.v4().substring(0, 8).toUpperCase();

  static String generatePatientId() =>
      'MR-${DateTime.now().year}-${_uuid.v4().substring(0, 4).toUpperCase()}';
}
