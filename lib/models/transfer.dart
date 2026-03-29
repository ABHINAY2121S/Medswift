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
  final String action; // 'viewed', 'reviewed', 'flagged', 'noted', 'created'

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

class TransferAttachment {
  final String fileName;
  final String base64Data;
  final String mimeType;

  TransferAttachment({
    required this.fileName,
    required this.base64Data,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'base64Data': base64Data,
    'mimeType': mimeType,
  };

  factory TransferAttachment.fromJson(Map<String, dynamic> j) => TransferAttachment(
    fileName: j['fileName'] ?? '',
    base64Data: j['base64Data'] ?? '',
    mimeType: j['mimeType'] ?? 'application/octet-stream',
  );

  /// Returns approximate file size in human-readable form
  String get sizeLabel {
    final bytes = (base64Data.length * 3 / 4).round();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage =>
      mimeType.startsWith('image/');
}

class PatientTransfer {
  final String id;
  // Patient info
  final String patientName;
  final int patientAge;
  final String patientGender;
  final String patientId;
  final String patientPhone; // normalized +91XXXXXXXXXX — used to sync to patient dashboard
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
  final int riskScore;    // 0–100 percentage
  final String sendingHospital;
  final String sendingDoctor;
  final String receivingHospital;
  final DateTime createdAt;
  // Comorbidities (e.g. ['Diabetes Type 2', 'Hypothyroidism', 'HTN'])
  List<String> comorbidities;
  // Status
  bool isReviewed;
  String? arrivalNote;
  bool isFlagged;
  List<AccessLog> accessLogs;
  String status; // 'pending', 'en_route', 'received', 'completed'
  // Attachments
  List<TransferAttachment> attachments;
  // Real-time transfer tracking
  DateTime? dispatchTime;  // when ambulance departed
  int etaMinutes;          // estimated minutes to destination
  // QR Access Control
  String qrPin;            // 4-digit PIN (plain, stored in Firestore securely)
  DateTime qrExpiresAt;    // QR link valid for 24h after generation

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
    this.riskScore = 0,
    required this.sendingHospital,
    required this.sendingDoctor,
    this.receivingHospital = '',
    required this.createdAt,
    List<String>? comorbidities,
    this.isReviewed = false,
    this.arrivalNote,
    this.isFlagged = false,
    List<AccessLog>? accessLogs,
    this.status = 'pending',
    List<TransferAttachment>? attachments,
    this.dispatchTime,
    this.etaMinutes = 30,
    String? qrPin,
    DateTime? qrExpiresAt,
  })  : comorbidities = comorbidities ?? [],
        accessLogs = accessLogs ?? [],
        attachments = attachments ?? [],
        qrPin = qrPin ?? _generatePin(),
        qrExpiresAt = qrExpiresAt ?? DateTime.now().add(const Duration(hours: 24));

  static String _generatePin() {
    final rand = DateTime.now().millisecondsSinceEpoch % 10000;
    return rand.toString().padLeft(4, '0');
  }

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
    'riskScore': riskScore,
    'sendingHospital': sendingHospital,
    'sendingDoctor': sendingDoctor,
    'receivingHospital': receivingHospital,
    'createdAt': createdAt.toIso8601String(),
    'comorbidities': comorbidities,
    'isReviewed': isReviewed,
    'arrivalNote': arrivalNote,
    'isFlagged': isFlagged,
    'accessLogs': accessLogs.map((l) => l.toJson()).toList(),
    'status': status,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'dispatchTime': dispatchTime?.toIso8601String(),
    'etaMinutes': etaMinutes,
    'qrPin': qrPin,
    'qrExpiresAt': qrExpiresAt.toIso8601String(),
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
    riskScore: j['riskScore'] ?? 0,
    sendingHospital: j['sendingHospital'],
    sendingDoctor: j['sendingDoctor'],
    receivingHospital: j['receivingHospital'] ?? '',
    createdAt: DateTime.parse(j['createdAt']),
    comorbidities: (j['comorbidities'] as List<dynamic>? ?? [])
        .map((c) => c.toString())
        .toList(),
    isReviewed: j['isReviewed'] ?? false,
    arrivalNote: j['arrivalNote'],
    isFlagged: j['isFlagged'] ?? false,
    accessLogs: (j['accessLogs'] as List<dynamic>? ?? [])
        .map((l) => AccessLog.fromJson(l))
        .toList(),
    status: j['status'] ?? 'pending',
    attachments: (j['attachments'] as List<dynamic>? ?? [])
        .map((a) => TransferAttachment.fromJson(a))
        .toList(),
    dispatchTime: j['dispatchTime'] != null
        ? DateTime.tryParse(j['dispatchTime'])
        : null,
    etaMinutes: j['etaMinutes'] ?? 30,
    qrPin: j['qrPin'] ?? _generatePin(),
    qrExpiresAt: j['qrExpiresAt'] != null
        ? DateTime.tryParse(j['qrExpiresAt']) ?? DateTime.now().add(const Duration(hours: 24))
        : DateTime.now().add(const Duration(hours: 24)),
  );

  /// Minimal JSON for QR — excludes large fields (attachments, access logs, clinical summary).
  /// QR codes have a ~4KB limit so we only include critical clinical data.
  Map<String, dynamic> toJsonMinimal() => {
    'id': id,
    'patientName': patientName,
    'patientAge': patientAge,
    'patientGender': patientGender,
    'patientId': patientId,
    'patientPhone': patientPhone,
    'diagnosis': diagnosis,
    'allergies': allergies,
    'medications': medications,
    // Truncate long fields to keep QR scannable
    'transferReason': transferReason.length > 200
        ? '${transferReason.substring(0, 200)}…'
        : transferReason,
    'vitals': vitals.toJson(),
    'riskLevel': riskLevel,
    'riskScore': riskScore,
    'sendingHospital': sendingHospital,
    'sendingDoctor': sendingDoctor,
    'receivingHospital': receivingHospital,
    'createdAt': createdAt.toIso8601String(),
    'comorbidities': comorbidities,
    'status': status,
    'isReviewed': isReviewed,
    'isFlagged': isFlagged,
  };

  /// Base64-encode the MINIMAL payload (no attachments) — safe for QR codes.
  String toBase64() => base64Encode(utf8.encode(jsonEncode(toJsonMinimal())));

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
    final expMs = qrExpiresAt.millisecondsSinceEpoch;
    // PIN is embedded as plain text — viewer.html hashes then compares on client side
    return 'https://abhinay2121s.github.io/Medswift/viewer.html?data=$encoded&pin=$qrPin&exp=$expMs';
  }

  String get shortLink => 'medswift.app/t/$id';
}
