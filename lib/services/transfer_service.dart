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
  static String suggestRisk(Vitals v, String diagnosis) {
    final criticalDx = ['infarction', 'stroke', 'hemorrhage', 'trauma', 'sepsis', 'cardiac', 'arrest', 'failure'];
    final diagLower = diagnosis.toLowerCase();
    for (final dx in criticalDx) {
      if (diagLower.contains(dx)) return 'critical';
    }
    // Check vitals
    if (v.pulse.isNotEmpty) {
      final pulse = int.tryParse(v.pulse) ?? 0;
      if (pulse > 120 || pulse < 50) return 'critical';
      if (pulse > 100) return 'moderate';
    }
    if (v.bp.contains('/')) {
      final parts = v.bp.split('/');
      final sys = int.tryParse(parts[0]) ?? 120;
      if (sys < 90 || sys > 180) return 'critical';
      if (sys < 100 || sys > 160) return 'moderate';
    }
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
