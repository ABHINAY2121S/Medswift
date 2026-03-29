import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';

/// PIN-based auth service — no OTP, no Firebase Auth.
/// Authentication is done by looking up phone + comparing pinHash in Firestore.
class AuthService {
  static final _db = FirebaseFirestore.instance;

  static const _doctorSessionKey = 'session_doctor_phone';
  static const _patientSessionKey = 'session_patient_phone';

  // ─── PIN Hashing ─────────────────────────────────────────────────────────

  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  static String normalizePhone(String phone) {
    String p = phone.trim().replaceAll(' ', '').replaceAll('-', '');
    if (!p.startsWith('+')) p = '+91$p';
    return p;
  }

  // ─── Hospitals ───────────────────────────────────────────────────────────

  static Future<HospitalProfile> registerHospital({
    required String name,
    required String licenseNo,
    required String city,
    required String phone,
  }) async {
    final existing = await _db
        .collection('hospitals')
        .where('licenseNo', isEqualTo: licenseNo.toUpperCase())
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return HospitalProfile.fromJson(existing.docs.first.data());
    }
    final id = 'HSP-${DateTime.now().millisecondsSinceEpoch}';
    final hospital = HospitalProfile(
      id: id,
      name: name,
      licenseNo: licenseNo.toUpperCase(),
      city: city,
      phone: normalizePhone(phone),
      registeredAt: DateTime.now(),
    );
    await _db.collection('hospitals').doc(id).set(hospital.toJson());
    return hospital;
  }

  static Future<HospitalProfile?> getHospitalByPhone(String phone) async {
    final snap = await _db
        .collection('hospitals')
        .where('phone', isEqualTo: normalizePhone(phone))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return HospitalProfile.fromJson(snap.docs.first.data());
  }

  static Future<List<HospitalProfile>> getHospitals() async {
    try {
      final snap = await _db.collection('hospitals').get();
      return snap.docs.map((d) => HospitalProfile.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Doctors ─────────────────────────────────────────────────────────────

  /// Register a new doctor. Returns error string on failure, null on success.
  static Future<String?> registerDoctor({
    required String name,
    required String phone,
    required String pin,
    required String hospitalId,
    required String hospitalName,
    required String licenseNo,
    String role = 'doctor',
    String speciality = '',
  }) async {
    final normPhone = normalizePhone(phone);
    try {
      final existing = await _db.collection('doctors').doc(normPhone).get();
      if (existing.exists) return 'Phone already registered as a doctor.';

      final doctor = DoctorProfile(
        id: normPhone,
        name: name,
        phone: normPhone,
        hospitalId: hospitalId,
        hospitalName: hospitalName,
        licenseNo: licenseNo,
        role: role,
        pinHash: hashPin(pin),
        speciality: speciality,
        totalTransfers: 0,
        completedTransfers: 0,
        registeredAt: DateTime.now(),
      );
      await _db.collection('doctors').doc(normPhone).set(doctor.toJson());
      await _saveSession(_doctorSessionKey, normPhone);
      return null; // success
    } catch (e) {
      return 'Registration failed: ${e.toString()}';
    }
  }

  /// Fetch all doctors from Firestore (for recommendation engine).
  static Future<List<DoctorProfile>> getAllDoctors() async {
    try {
      final snap = await _db.collection('doctors').get();
      return snap.docs.map((d) => DoctorProfile.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// App-tracked: atomically increment a doctor's transfer counters.
  /// [completed] = true → also increments completedTransfers.
  static Future<void> incrementDoctorStats(String doctorPhone, {bool completed = false}) async {
    final normPhone = normalizePhone(doctorPhone);
    try {
      final updates = <String, dynamic>{
        'totalTransfers': FieldValue.increment(1),
      };
      if (completed) {
        updates['completedTransfers'] = FieldValue.increment(1);
      }
      await _db.collection('doctors').doc(normPhone).update(updates);
    } catch (_) {
      // Doctor doc may not exist yet — silently ignore
    }
  }

  /// Login doctor with phone + PIN. Returns error string or null on success.
  static Future<({DoctorProfile? doctor, String? error})> loginDoctorWithPin({
    required String phone,
    required String pin,
  }) async {
    final normPhone = normalizePhone(phone);
    try {
      final snap = await _db.collection('doctors').doc(normPhone).get();
      if (!snap.exists) {
        return (doctor: null, error: 'Phone not registered as a doctor.');
      }
      final doctor = DoctorProfile.fromJson(snap.data()!);
      if (doctor.pinHash != hashPin(pin)) {
        return (doctor: null, error: 'Incorrect PIN. Please try again.');
      }
      await _saveSession(_doctorSessionKey, normPhone);
      return (doctor: doctor, error: null);
    } catch (e) {
      return (doctor: null, error: 'Login failed. Check your connection.');
    }
  }

  static Future<DoctorProfile?> getDoctorByPhone(String phone) async {
    final normPhone = normalizePhone(phone);
    try {
      final snap = await _db.collection('doctors').doc(normPhone).get();
      if (!snap.exists) return null;
      return DoctorProfile.fromJson(snap.data()!);
    } catch (_) {
      return null;
    }
  }

  static Future<DoctorProfile?> getCurrentDoctor() async {
    final savedPhone = await _getSession(_doctorSessionKey);
    if (savedPhone == null) return null;
    return getDoctorByPhone(savedPhone);
  }

  static Future<void> logoutDoctor() async {
    await _clearSession(_doctorSessionKey);
  }

  // ─── Patients ─────────────────────────────────────────────────────────────

  /// Register a new patient. Returns error string on failure, null on success.
  static Future<({PatientProfile? patient, String? error})> registerPatient({
    required String name,
    required String phone,
    required String pin,
    required String dob,
  }) async {
    final normPhone = normalizePhone(phone);
    try {
      final existing = await _db.collection('patients').doc(normPhone).get();
      if (existing.exists) {
        return (patient: null, error: 'Phone already registered. Please login.');
      }

      // Generate patient MR number
      final countSnap = await _db.collection('patients').count().get();
      final serial = ((countSnap.count ?? 0) + 1).toString().padLeft(4, '0');
      final patientId = 'MR-${DateTime.now().year}-$serial';

      final patient = PatientProfile(
        id: normPhone,
        patientId: patientId,
        name: name,
        phone: normPhone,
        dob: dob,
        pinHash: hashPin(pin),
        registeredAt: DateTime.now(),
      );
      await _db.collection('patients').doc(normPhone).set(patient.toJson());
      await _saveSession(_patientSessionKey, normPhone);
      return (patient: patient, error: null);
    } catch (e) {
      return (patient: null, error: 'Registration failed: ${e.toString()}');
    }
  }

  /// Login patient with phone + PIN.
  static Future<({PatientProfile? patient, String? error})> loginPatientWithPin({
    required String phone,
    required String pin,
  }) async {
    final normPhone = normalizePhone(phone);
    try {
      final snap = await _db.collection('patients').doc(normPhone).get();
      if (!snap.exists) {
        return (patient: null, error: 'Phone not registered. Please register first.');
      }
      final patient = PatientProfile.fromJson(snap.data()!);
      if (patient.pinHash != hashPin(pin)) {
        return (patient: null, error: 'Incorrect PIN. Please try again.');
      }
      await _saveSession(_patientSessionKey, normPhone);
      return (patient: patient, error: null);
    } catch (e) {
      return (patient: null, error: 'Login failed. Check your connection.');
    }
  }

  static Future<PatientProfile?> getPatientByPhone(String phone) async {
    final normPhone = normalizePhone(phone);
    try {
      final snap = await _db.collection('patients').doc(normPhone).get();
      if (!snap.exists) return null;
      return PatientProfile.fromJson(snap.data()!);
    } catch (_) {
      return null;
    }
  }

  static Future<PatientProfile?> getCurrentPatient() async {
    final savedPhone = await _getSession(_patientSessionKey);
    if (savedPhone == null) return null;
    return getPatientByPhone(savedPhone);
  }

  static Future<String?> getCurrentPatientPhone() async {
    return _getSession(_patientSessionKey);
  }

  static Future<void> logoutPatient() async {
    await _clearSession(_patientSessionKey);
  }

  // ─── Session helpers ──────────────────────────────────────────────────────

  static Future<void> _saveSession(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> _getSession(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> _clearSession(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
