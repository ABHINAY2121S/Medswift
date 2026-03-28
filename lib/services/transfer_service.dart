import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer.dart';

class TransferService {
  static const _storageKey = 'transfers';
  static const _patientKey = 'patient_id';
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
  /// Clinical thresholds:
  ///   BP: Critical if systolic <80 or >180; Moderate if <90 or >160
  ///   HR: Critical if <40 or >130; Moderate if <60 or >100
  ///   SpO2: Critical if <90%; Moderate if <95%
  ///   Temp (°F): Critical if <95 or >104; Moderate if >100.4
  static String suggestRisk(Vitals v, String diagnosis) {
    int score = 0; // 0=safe, 1=moderate, 2=critical

    // ── Diagnosis keywords ─────────────────────────────────────────────────
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

    // ── Heart Rate ─────────────────────────────────────────────────────────
    if (v.pulse.isNotEmpty) {
      final hr = int.tryParse(v.pulse.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (hr > 0) {
        if (hr < 40 || hr > 130) score = 2;
        else if ((hr < 60 || hr > 100) && score < 2) score = score < 1 ? 1 : score;
      }
    }

    // ── Blood Pressure ──────────────────────────────────────────────────────
    if (v.bp.contains('/')) {
      final parts = v.bp.split('/');
      final sys = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 120;
      final dia = parts.length > 1
          ? (int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 80)
          : 80;
      if (sys < 80 || sys > 180 || dia > 120) score = 2;
      else if ((sys < 90 || sys > 160 || dia > 100) && score < 2) score = score < 1 ? 1 : score;
    }

    // ── SpO2 ───────────────────────────────────────────────────────────────
    if (v.spo2.isNotEmpty) {
      final spo2 = int.tryParse(v.spo2.replaceAll(RegExp(r'[^0-9]'), '')) ?? 100;
      if (spo2 < 90) score = 2;
      else if (spo2 < 95 && score < 2) score = score < 1 ? 1 : score;
    }

    // ── Temperature (°F) ──────────────────────────────────────────────────
    if (v.temp.isNotEmpty) {
      final tempStr = v.temp.replaceAll(RegExp(r'[^0-9.]'), '');
      final temp = double.tryParse(tempStr) ?? 98.6;
      // If entered in Celsius (values <45), convert to °F
      final tempF = temp < 45 ? (temp * 9 / 5) + 32 : temp;
      if (tempF < 95.0 || tempF > 104.0) score = 2;
      else if (tempF > 100.4 && score < 2) score = score < 1 ? 1 : score;
    }

    if (score >= 2) return 'critical';
    if (score == 1) return 'moderate';
    return 'safe';
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  static Future<List<PatientTransfer>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return _seedData();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((j) => PatientTransfer.fromJson(j)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> save(PatientTransfer t) async {
    final all = await getAll();
    final idx = all.indexWhere((x) => x.id == t.id);
    if (idx >= 0) {
      all[idx] = t;
    } else {
      all.insert(0, t);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(all.map((x) => x.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((x) => x.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(all.map((x) => x.toJson()).toList()));
  }

  static Future<PatientTransfer?> getById(String id) async {
    final all = await getAll();
    try {
      return all.firstWhere((x) => x.id == id);
    } catch (_) {
      return null;
    }
  }

  static String generateId() => _uuid.v4().substring(0, 8).toUpperCase();

  static String generatePatientId() => 'MR-${DateTime.now().year}-${_uuid.v4().substring(0, 4).toUpperCase()}';

  // ── Patient auth mock ─────────────────────────────────────────────────────
  static Future<String?> getPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_patientKey);
  }

  static Future<void> setPatientId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_patientKey, id);
  }

  static Future<List<PatientTransfer>> getPatientTransfers(String patientId) async {
    final all = await getAll();
    // In real app, filter by patient ID. For demo, return all.
    return all;
  }

  // ── Seed data ─────────────────────────────────────────────────────────────
  static List<PatientTransfer> _seedData() {
    final now = DateTime.now();
    return [
      PatientTransfer(
        id: 'A1B2C3D4',
        patientName: 'Amir Patel',
        patientAge: 58,
        patientGender: 'Male',
        patientId: 'MR-2024-0847',
        patientPhone: '+91 9876543210',
        diagnosis: 'Acute Myocardial Infarction',
        allergies: 'Penicillin, Sulfa drugs',
        medications: 'Aspirin 81mg, Metoprolol 50mg, Atorvastatin 40mg',
        clinicalSummary: 'Patient presented with chest pain radiating to left arm. ECG shows STEMI. Immediate intervention required. Troponin levels elevated at 2.4 ng/mL.',
        transferReason: 'Requires cardiac catheterization — not available at current facility',
        vitals: Vitals(bp: '90/60', pulse: '112', temp: '99.1', spo2: '94%'),
        riskLevel: 'critical',
        sendingHospital: 'City General Hospital',
        sendingDoctor: 'Dr. James Wilson',
        receivingHospital: 'Metro Heart Center',
        createdAt: now.subtract(const Duration(minutes: 14)),
        isReviewed: false,
        status: 'en_route',
        accessLogs: [
          AccessLog(
            doctorName: 'Dr. James Wilson',
            hospital: 'City General Hospital',
            timestamp: now.subtract(const Duration(minutes: 14)),
            action: 'created',
          ),
        ],
      ),
      PatientTransfer(
        id: 'E5F6G7H8',
        patientName: 'Lisa Wong',
        patientAge: 34,
        patientGender: 'Female',
        patientId: 'MR-2024-0846',
        diagnosis: 'Femur Fracture — Open Reduction Needed',
        allergies: 'None known',
        medications: 'Morphine 5mg PRN, Enoxaparin 40mg',
        clinicalSummary: 'Patient sustained femur fracture in MVA. Hemodynamically stable. Ortho surgery required.',
        transferReason: 'Orthopaedic surgery not available at current facility',
        vitals: Vitals(bp: '118/76', pulse: '88', temp: '98.6', spo2: '98%'),
        riskLevel: 'moderate',
        sendingHospital: 'Riverside Clinic',
        sendingDoctor: 'Dr. Nina Kapoor',
        createdAt: now.subtract(const Duration(hours: 2)),
        status: 'pending',
      ),
      PatientTransfer(
        id: 'I9J0K1L2',
        patientName: 'James Rivera',
        patientAge: 65,
        patientGender: 'Male',
        patientId: 'MR-2024-0845',
        diagnosis: 'Post-CABG Follow-up',
        allergies: 'Latex',
        medications: 'Warfarin 5mg, Atenolol 25mg, Lisinopril 10mg',
        clinicalSummary: 'Stable post-surgical patient needing specialist follow-up.',
        transferReason: 'Specialist follow-up care at tertiary center',
        vitals: Vitals(bp: '130/82', pulse: '68', temp: '98.2', spo2: '99%'),
        riskLevel: 'safe',
        sendingHospital: 'Sunrise Medical',
        sendingDoctor: 'Dr. Sarah Chen',
        createdAt: now.subtract(const Duration(hours: 5)),
        isReviewed: true,
        status: 'completed',
      ),
    ];
  }
}
