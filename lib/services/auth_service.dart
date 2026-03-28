import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';

/// AuthService wraps Firebase Phone Auth + Firestore.
/// OTP is sent by Firebase — real SMS via Google's infrastructure.
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static const _doctorSessionKey = 'session_doctor_id';
  static const _patientSessionKey = 'session_patient_id';

  // ─── Phone OTP via Firebase ──────────────────────────────────────────────

  /// Sends OTP to [phone]. On success calls [onCodeSent] with verificationId.
  /// On error calls [onError] with a user-friendly message.
  static Future<void> sendOtp(
    String phone, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential)? onAutoVerified,
  }) async {
    // Ensure E.164 format (+91XXXXXXXXXX)
    String e164 = phone.trim();
    if (!e164.startsWith('+')) e164 = '+91$e164';

    await _auth.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) {
        // Auto-fill on Android (SMS auto-read)
        onAutoVerified?.call(credential);
      },
      verificationFailed: (e) {
        String msg;
        switch (e.code) {
          case 'invalid-phone-number':
            msg = 'Invalid phone number format.';
            break;
          case 'too-many-requests':
            msg = 'Too many attempts. Try again later.';
            break;
          case 'quota-exceeded':
            msg = 'SMS quota exceeded. Contact support.';
            break;
          default:
            msg = e.message ?? 'SMS failed. Check your number.';
        }
        onError(msg);
      },
      codeSent: (verificationId, resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Signs in with [verificationId] and [smsCode] entered by user.
  /// Returns the FirebaseAuth [User] on success, throws on failure.
  static Future<User> verifyOtp(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  /// Signs in using an auto-verified credential (Android SMS auto-read).
  static Future<User> signInWithCredential(PhoneAuthCredential c) async {
    final result = await _auth.signInWithCredential(c);
    return result.user!;
  }

  static User? get currentFirebaseUser => _auth.currentUser;

  // ─── Hospitals ───────────────────────────────────────────────────────────

  static Future<HospitalProfile> registerHospital({
    required String name,
    required String licenseNo,
    required String city,
    required String phone,
  }) async {
    // Check if already registered
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
      phone: phone,
      registeredAt: DateTime.now(),
    );
    await _db.collection('hospitals').doc(id).set(hospital.toJson());
    return hospital;
  }

  static Future<HospitalProfile?> getHospitalByPhone(String phone) async {
    final snap = await _db
        .collection('hospitals')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return HospitalProfile.fromJson(snap.docs.first.data());
  }

  static Future<List<HospitalProfile>> getHospitals() async {
    final snap = await _db.collection('hospitals').get();
    return snap.docs.map((d) => HospitalProfile.fromJson(d.data())).toList();
  }

  // ─── Doctors ─────────────────────────────────────────────────────────────

  static Future<DoctorProfile> registerDoctor({
    required String uid,
    required String name,
    required String phone,
    required String hospitalId,
    required String hospitalName,
    required String licenseNo,
    String role = 'doctor',
  }) async {
    final existing = await _db.collection('doctors').doc(uid).get();
    if (existing.exists) return DoctorProfile.fromJson(existing.data()!);

    final doctor = DoctorProfile(
      id: uid,
      name: name,
      phone: phone,
      hospitalId: hospitalId,
      hospitalName: hospitalName,
      licenseNo: licenseNo,
      role: role,
      registeredAt: DateTime.now(),
    );
    await _db.collection('doctors').doc(uid).set(doctor.toJson());
    await _saveSession(_doctorSessionKey, uid);
    return doctor;
  }

  static Future<DoctorProfile?> getDoctorByUid(String uid) async {
    final snap = await _db.collection('doctors').doc(uid).get();
    if (!snap.exists) return null;
    return DoctorProfile.fromJson(snap.data()!);
  }

  static Future<DoctorProfile?> getDoctorByPhone(String phone) async {
    final snap = await _db
        .collection('doctors')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DoctorProfile.fromJson(snap.docs.first.data());
  }

  static Future<void> loginDoctor(DoctorProfile doctor) async {
    await _saveSession(_doctorSessionKey, doctor.id);
  }

  static Future<DoctorProfile?> getCurrentDoctor() async {
    // First try Firebase Auth UID
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final doc = await getDoctorByUid(uid);
      if (doc != null) return doc;
    }
    // Fallback to saved session
    final savedId = await _getSession(_doctorSessionKey);
    if (savedId == null) return null;
    return getDoctorByUid(savedId);
  }

  static Future<void> logoutDoctor() async {
    await _auth.signOut();
    await _clearSession(_doctorSessionKey);
  }

  // ─── Patients ─────────────────────────────────────────────────────────────

  static Future<PatientProfile> registerPatient({
    required String uid,
    required String name,
    required String phone,
    required String dob,
  }) async {
    final existing = await _db.collection('patients').doc(uid).get();
    if (existing.exists) return PatientProfile.fromJson(existing.data()!);

    // Generate patient MR number
    final countSnap = await _db.collection('patients').count().get();
    final serial = ((countSnap.count ?? 0) + 1).toString().padLeft(4, '0');
    final patientId = 'MR-${DateTime.now().year}-$serial';

    final patient = PatientProfile(
      id: uid,
      patientId: patientId,
      name: name,
      phone: phone,
      dob: dob,
      registeredAt: DateTime.now(),
    );
    await _db.collection('patients').doc(uid).set(patient.toJson());
    await _saveSession(_patientSessionKey, uid);
    return patient;
  }

  static Future<PatientProfile?> getPatientByUid(String uid) async {
    final snap = await _db.collection('patients').doc(uid).get();
    if (!snap.exists) return null;
    return PatientProfile.fromJson(snap.data()!);
  }

  static Future<PatientProfile?> getPatientByPhone(String phone) async {
    final snap = await _db
        .collection('patients')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return PatientProfile.fromJson(snap.docs.first.data());
  }

  static Future<void> loginPatient(PatientProfile patient) async {
    await _saveSession(_patientSessionKey, patient.id);
  }

  static Future<PatientProfile?> getCurrentPatient() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final p = await getPatientByUid(uid);
      if (p != null) return p;
    }
    final savedId = await _getSession(_patientSessionKey);
    if (savedId == null) return null;
    return getPatientByUid(savedId);
  }

  static Future<void> logoutPatient() async {
    await _auth.signOut();
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
