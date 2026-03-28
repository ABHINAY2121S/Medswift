class DoctorProfile {
  final String id;        // phone (normalized, e.g. +919876543210)
  final String name;
  final String phone;
  final String hospitalId;
  final String hospitalName;
  final String licenseNo;
  final String role; // 'doctor', 'nurse', 'admin'
  final String pinHash; // SHA-256 of the 4-digit PIN
  final DateTime registeredAt;

  DoctorProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.hospitalId,
    required this.hospitalName,
    required this.licenseNo,
    this.role = 'doctor',
    required this.pinHash,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'hospitalId': hospitalId,
    'hospitalName': hospitalName,
    'licenseNo': licenseNo,
    'role': role,
    'pinHash': pinHash,
    'registeredAt': registeredAt.toIso8601String(),
  };

  factory DoctorProfile.fromJson(Map<String, dynamic> j) => DoctorProfile(
    id: j['id'],
    name: j['name'],
    phone: j['phone'],
    hospitalId: j['hospitalId'],
    hospitalName: j['hospitalName'],
    licenseNo: j['licenseNo'] ?? '',
    role: j['role'] ?? 'doctor',
    pinHash: j['pinHash'] ?? '',
    registeredAt: DateTime.parse(j['registeredAt']),
  );
}

class HospitalProfile {
  final String id;
  final String name;
  final String licenseNo;
  final String city;
  final String phone;
  final DateTime registeredAt;

  HospitalProfile({
    required this.id,
    required this.name,
    required this.licenseNo,
    required this.city,
    required this.phone,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'licenseNo': licenseNo,
    'city': city,
    'phone': phone,
    'registeredAt': registeredAt.toIso8601String(),
  };

  factory HospitalProfile.fromJson(Map<String, dynamic> j) => HospitalProfile(
    id: j['id'],
    name: j['name'],
    licenseNo: j['licenseNo'],
    city: j['city'] ?? '',
    phone: j['phone'],
    registeredAt: DateTime.parse(j['registeredAt']),
  );
}

class PatientProfile {
  final String id;        // phone (normalized)
  final String patientId; // e.g. MR-2024-XXXX
  final String name;
  final String phone;
  final String dob; // DD/MM/YYYY
  final String pinHash; // SHA-256 of the 4-digit PIN
  final DateTime registeredAt;

  PatientProfile({
    required this.id,
    required this.patientId,
    required this.name,
    required this.phone,
    required this.dob,
    required this.pinHash,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'name': name,
    'phone': phone,
    'dob': dob,
    'pinHash': pinHash,
    'registeredAt': registeredAt.toIso8601String(),
  };

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
    id: j['id'],
    patientId: j['patientId'],
    name: j['name'],
    phone: j['phone'],
    dob: j['dob'] ?? '',
    pinHash: j['pinHash'] ?? '',
    registeredAt: DateTime.parse(j['registeredAt']),
  );
}
