import 'dart:convert';

class Vitals {
  final String bp;
  final String pulse;
  final String temp;
  final String spo2;

  Vitals({
    this.bp = '',
    this.pulse = '',
    this.temp = '',
    this.spo2 = '',
  });

  Map<String, dynamic> toJson() => {
    'bp': bp, 'pulse': pulse, 'temp': temp, 'spo2': spo2,
  };

  factory Vitals.fromJson(Map<String, dynamic> j) => Vitals(
    bp: j['bp'] ?? '', pulse: j['pulse'] ?? '',
    temp: j['temp'] ?? '', spo2: j['spo2'] ?? '',
  );
}

class AccessLog {
  final String doctorName;
  final String hospital;
  final DateTime timestamp;
  final String action; // 'viewed', 'reviewed', 'flagged', 'noted'

  AccessLog({
    required this.doctorName,
    required this.hospital,
    required this.timestamp,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
    'doctorName': doctorName,
    'hospital': hospital,
    'timestamp': timestamp.toIso8601String(),
    'action': action,
  };

  factory AccessLog.fromJson(Map<String, dynamic> j) => AccessLog(
    doctorName: j['doctorName'] ?? '',
    hospital: j['hospital'] ?? '',
    timestamp: DateTime.parse(j['timestamp']),
    action: j['action'] ?? '',
  );
}

class PatientTransfer {
  final String id;
  // Patient info
  final String patientName;
  final int patientAge;
  final String patientGender;
  final String patientId;
  final String patientPhone;
  // Clinical
  final String diagnosis;
  final String allergies;
  final String medications;
  final String clinicalSummary;
  final String transferReason;
  // Vitals
  final Vitals vitals;
  // Transfer info
  final String riskLevel; // safe, moderate, critical
  final String sendingHospital;
  final String sendingDoctor;
  final String receivingHospital;
  final DateTime createdAt;
  // Status
  bool isReviewed;
  String? arrivalNote;
  bool isFlagged;
  List<AccessLog> accessLogs;
  String status; // 'pending', 'en_route', 'received', 'completed'

  PatientTransfer({
    required this.id,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.patientId,
    this.patientPhone = '',
    required this.diagnosis,
    required this.allergies,
    required this.medications,
    required this.clinicalSummary,
    required this.transferReason,
    required this.vitals,
    required this.riskLevel,
    required this.sendingHospital,
    required this.sendingDoctor,
    this.receivingHospital = '',
    required this.createdAt,
    this.isReviewed = false,
    this.arrivalNote,
    this.isFlagged = false,
    List<AccessLog>? accessLogs,
    this.status = 'pending',
  }) : accessLogs = accessLogs ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientName': patientName,
    'patientAge': patientAge,
    'patientGender': patientGender,
    'patientId': patientId,
    'patientPhone': patientPhone,
    'diagnosis': diagnosis,
    'allergies': allergies,
    'medications': medications,
    'clinicalSummary': clinicalSummary,
    'transferReason': transferReason,
    'vitals': vitals.toJson(),
    'riskLevel': riskLevel,
    'sendingHospital': sendingHospital,
    'sendingDoctor': sendingDoctor,
    'receivingHospital': receivingHospital,
    'createdAt': createdAt.toIso8601String(),
    'isReviewed': isReviewed,
    'arrivalNote': arrivalNote,
    'isFlagged': isFlagged,
    'accessLogs': accessLogs.map((l) => l.toJson()).toList(),
    'status': status,
  };

  factory PatientTransfer.fromJson(Map<String, dynamic> j) => PatientTransfer(
    id: j['id'],
    patientName: j['patientName'],
    patientAge: j['patientAge'],
    patientGender: j['patientGender'],
    patientId: j['patientId'],
    patientPhone: j['patientPhone'] ?? '',
    diagnosis: j['diagnosis'],
    allergies: j['allergies'],
    medications: j['medications'],
    clinicalSummary: j['clinicalSummary'] ?? '',
    transferReason: j['transferReason'],
    vitals: Vitals.fromJson(j['vitals'] ?? {}),
    riskLevel: j['riskLevel'],
    sendingHospital: j['sendingHospital'],
    sendingDoctor: j['sendingDoctor'],
    receivingHospital: j['receivingHospital'] ?? '',
    createdAt: DateTime.parse(j['createdAt']),
    isReviewed: j['isReviewed'] ?? false,
    arrivalNote: j['arrivalNote'],
    isFlagged: j['isFlagged'] ?? false,
    accessLogs: (j['accessLogs'] as List<dynamic>? ?? [])
        .map((l) => AccessLog.fromJson(l))
        .toList(),
    status: j['status'] ?? 'pending',
  );

  String toBase64() => base64Encode(utf8.encode(jsonEncode(toJson())));

  static PatientTransfer? fromBase64(String encoded) {
    try {
      final json = jsonDecode(utf8.decode(base64Decode(encoded)));
      return PatientTransfer.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  String get viewerUrl {
    final encoded = toBase64();
    return 'https://medswift.app/view?data=$encoded';
  }

  String get shortLink => 'medswift.app/t/$id';
}
