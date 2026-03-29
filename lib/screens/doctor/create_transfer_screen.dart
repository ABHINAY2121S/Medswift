import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../models/auth_models.dart';
import '../../services/transfer_service.dart';
import '../../services/auth_service.dart';
import 'qr_display_screen.dart';

class CreateTransferScreen extends StatefulWidget {
  const CreateTransferScreen({super.key});

  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _patientPhoneCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medsCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _receivingHospitalCtrl = TextEditingController();

  String _gender = 'Male';
  String _riskLevel = 'moderate';
  String _suggestedRisk = 'moderate';
  int _riskPercent = 20; // live percentage from engine
  List<String> _conflicts = [];
  int _summaryWords = 0;
  bool _submitting = false;

  // Comorbidities chip selection
  static const List<Map<String, String>> _allComorbidities = [
    {'label': 'Diabetes Type 1', 'emoji': '🩸'},
    {'label': 'Diabetes Type 2', 'emoji': '🩸'},
    {'label': 'Hypothyroidism', 'emoji': '🦋'},
    {'label': 'Hyperthyroidism', 'emoji': '🦋'},
    {'label': 'Hypertension',   'emoji': '❤️'},
    {'label': 'CAD',            'emoji': '🫀'},
    {'label': 'Heart Failure',  'emoji': '🫀'},
    {'label': 'CKD',            'emoji': '🫘'},
    {'label': 'COPD',           'emoji': '🫁'},
    {'label': 'Asthma',         'emoji': '🌬️'},
    {'label': 'AF / Arrhythmia','emoji': '📈'},
    {'label': 'Cancer',         'emoji': '🔬'},
    {'label': 'HIV/Immunocomp.','emoji': '🛡️'},
    {'label': 'Transplant',     'emoji': '💉'},
  ];
  final Set<String> _selectedComorbidities = {};

  // Doctor info (auto-filled)
  DoctorProfile? _doctor;

  // Attachments
  final List<TransferAttachment> _attachments = [];
  bool _pickingFile = false;

  // Voice-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  String? _listeningField; // 'meds' | 'reason' | 'summary'

  @override
  void initState() {
    super.initState();
    _allergiesCtrl.addListener(_checkConflicts);
    _medsCtrl.addListener(_checkConflicts);
    _bpCtrl.addListener(_suggestRisk);
    _pulseCtrl.addListener(_suggestRisk);
    _tempCtrl.addListener(_suggestRisk);
    _spo2Ctrl.addListener(_suggestRisk);
    _diagnosisCtrl.addListener(_suggestRisk);
    _summaryCtrl.addListener(_updateWordCount);
    _loadDoctor();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (e) => _snack('Speech error: ${e.errorMsg}', err: true),
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  /// Starts listening into [fieldKey] controller.
  /// If already listening to the same field, stops instead.
  Future<void> _toggleListen(String fieldKey, TextEditingController ctrl) async {
    if (!_speechAvailable) {
      _snack('Microphone not available on this device', err: true);
      return;
    }
    if (_speech.isListening) {
      await _speech.stop();
      setState(() => _listeningField = null);
      return;
    }
    setState(() => _listeningField = fieldKey);
    final existing = ctrl.text.trim();
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords;
        ctrl.text = existing.isEmpty ? words : '$existing $words';
        ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: ctrl.text.length),
        );
      },
      listenFor: const Duration(minutes: 60),
      pauseFor: const Duration(minutes: 60),
      listenMode: stt.ListenMode.dictation,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
    // Auto-stop callback
    _speech.statusListener = (status) {
      if (status == 'done' || status == 'notListening') {
        if (mounted) setState(() => _listeningField = null);
      }
    };
  }

  Future<void> _loadDoctor() async {
    final doc = await AuthService.getCurrentDoctor();
    if (mounted) setState(() => _doctor = doc);
  }

  void _checkConflicts() {
    final c = TransferService.detectConflicts(_allergiesCtrl.text, _medsCtrl.text);
    setState(() => _conflicts = c);
  }

  void _suggestRisk() {
    final v = Vitals(
      bp: _bpCtrl.text, pulse: _pulseCtrl.text,
      temp: _tempCtrl.text, spo2: _spo2Ctrl.text,
    );
    final pct = TransferService.suggestRiskPercent(
      v, _diagnosisCtrl.text,
      comorbidities: _selectedComorbidities.toList(),
    );
    final r = TransferService.suggestRisk(
      v, _diagnosisCtrl.text,
      comorbidities: _selectedComorbidities.toList(),
    );
    setState(() { _suggestedRisk = r; _riskLevel = r; _riskPercent = pct; });
  }

  void _updateWordCount() {
    final words = _summaryCtrl.text.trim().split(RegExp(r'\s+'));
    setState(() => _summaryWords = _summaryCtrl.text.isEmpty ? 0 : words.length);
  }

  @override
  void dispose() {
    _speech.stop();
    for (final c in [
      _nameCtrl, _ageCtrl, _patientPhoneCtrl, _diagnosisCtrl, _allergiesCtrl,
      _medsCtrl, _bpCtrl, _pulseCtrl, _tempCtrl, _spo2Ctrl, _reasonCtrl,
      _summaryCtrl, _receivingHospitalCtrl
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── File picker ───────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );
      if (result != null) {
        for (final file in result.files) {
          if (file.bytes == null) continue;
          final sizeMB = file.bytes!.length / (1024 * 1024);
          if (sizeMB > 10) {
            _snack('${file.name} exceeds 10MB limit', err: true);
            continue;
          }
          final base64Data = base64Encode(file.bytes!);
          final mime = _mimeFromExt(file.extension ?? '');
          setState(() {
            _attachments.add(TransferAttachment(
              fileName: file.name,
              base64Data: base64Data,
              mimeType: mime,
            ));
          });
        }
      }
    } catch (e) {
      _snack('Could not pick file: $e', err: true);
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'pdf': return 'application/pdf';
      case 'doc': case 'docx': return 'application/msword';
      default: return 'application/octet-stream';
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final doctorName = _doctor?.name ?? 'Doctor';
    final hospitalName = _doctor?.hospitalName ?? 'Hospital';
    final rawPhone = _patientPhoneCtrl.text.trim();
    final normPhone = rawPhone.isEmpty ? '' : AuthService.normalizePhone(rawPhone);

    final transfer = PatientTransfer(
      id: TransferService.generateId(),
      patientName: _nameCtrl.text.trim(),
      patientAge: int.tryParse(_ageCtrl.text) ?? 0,
      patientGender: _gender,
      patientId: TransferService.generatePatientId(),
      patientPhone: normPhone,
      diagnosis: _diagnosisCtrl.text.trim(),
      allergies: _allergiesCtrl.text.trim(),
      medications: _medsCtrl.text.trim(),
      clinicalSummary: _summaryCtrl.text.trim(),
      transferReason: _reasonCtrl.text.trim(),
      vitals: Vitals(
        bp: _bpCtrl.text.trim(),
        pulse: _pulseCtrl.text.trim(),
        temp: _tempCtrl.text.trim(),
        spo2: _spo2Ctrl.text.trim(),
      ),
      comorbidities: _selectedComorbidities.toList(),
      riskLevel: _riskLevel,
      riskScore: _riskPercent,
      sendingHospital: hospitalName,
      sendingDoctor: doctorName,
      receivingHospital: _receivingHospitalCtrl.text.trim(),
      createdAt: DateTime.now(),
      attachments: _attachments,
      accessLogs: [
        AccessLog(
          doctorName: doctorName,
          hospital: hospitalName,
          timestamp: DateTime.now(),
          action: 'created',
        ),
      ],
    );

    await TransferService.save(transfer);
    setState(() => _submitting = false);

    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => QrDisplayScreen(transfer: transfer)));
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: err ? AppColors.danger : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Transfer'),
        leading: IconButton(
          icon: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.dark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Doctor info banner
            if (_doctor != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text('${_doctor!.name} • ${_doctor!.hospitalName}',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ).animate().fadeIn(),

            // Conflict Warning Banner
            if (_conflicts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.critical.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_rounded, color: AppColors.critical, size: 18),
                      const SizedBox(width: 8),
                      Text('Drug-Allergy Conflict Detected',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.critical, fontSize: 13)),
                    ]),
                    const SizedBox(height: 6),
                    ...(_conflicts.map((c) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(c,
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.critical)),
                    ))),
                  ],
                ),
              ).animate().fadeIn().shake(),
              const SizedBox(height: 16),
            ],

            _SectionHeader('Patient Information'),
            _buildCard([
              _field('Full Name *', _nameCtrl, validator: (v) => v!.isEmpty ? 'Required' : null),
              Row(children: [
                Expanded(child: _field('Age *', _ageCtrl,
                    type: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(child: _genderPicker()),
              ]),
              // ★ Patient phone field — KEY for sync
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Patient's Phone No.",
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _patientPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
                    decoration: InputDecoration(
                      hintText: '9876543210 (patient sees this in their app)',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 12),
                      prefixText: '+91 ',
                      prefixStyle: GoogleFonts.dmSans(
                          color: AppColors.primary, fontWeight: FontWeight.w600),
                      prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 18),
                      filled: true,
                      fillColor: AppColors.greenLight,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.accent.withOpacity(0.3))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Patient registered with this number will see this transfer',
                      style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.accent)),
                ],
              ),
              _field('Receiving Hospital (optional)', _receivingHospitalCtrl),
            ]),

            const SizedBox(height: 20),
            _SectionHeader('Clinical Details'),
            _buildCard([
              _field('Primary Diagnosis *', _diagnosisCtrl,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              _field('⚠ Allergies *', _allergiesCtrl,
                  filled: true,
                  fillColor: AppColors.redLight,
                  textColor: AppColors.critical,
                  hint: 'e.g. Penicillin, Sulfa drugs',
                  validator: (v) => v!.isEmpty ? 'Allergies required (enter None if none)' : null),
              _voiceField('Current Medications *', _medsCtrl, 'meds',
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
            ]),

            const SizedBox(height: 20),
            _SectionHeader('Comorbidities / Pre-existing Conditions'),
            _buildCard([
              Text('Select all that apply — affects risk calculation',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allComorbidities.map((c) {
                  final label = c['label']!;
                  final emoji = c['emoji']!;
                  final selected = _selectedComorbidities.contains(label);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedComorbidities.remove(label);
                        } else {
                          _selectedComorbidities.add(label);
                        }
                      });
                      _suggestRisk();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 6, spreadRadius: 0)]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppColors.dark,
                            ),
                          ),
                          if (selected) ...[ 
                            const SizedBox(width: 4),
                            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedComorbidities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_selectedComorbidities.length} condition(s) — risk score updated',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 20),
            _SectionHeader('Vitals'),
            _buildCard([
              Row(children: [
                Expanded(child: _field('BP', _bpCtrl, hint: '120/80')),
                const SizedBox(width: 8),
                Expanded(child: _field('Pulse', _pulseCtrl, hint: '72', type: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('Temp °F', _tempCtrl, hint: '98.6', type: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('SpO2 %', _spo2Ctrl, hint: '98%', type: TextInputType.number)),
              ]),
            ]),

            const SizedBox(height: 20),
            _SectionHeader('Transfer Details'),
            _buildCard([
              _voiceField('Reason for Transfer *', _reasonCtrl, 'reason',
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Clinical Summary',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted,
                              fontWeight: FontWeight.w500)),
                      Row(children: [
                        Text('$_summaryWords / 200 words',
                            style: GoogleFonts.dmSans(fontSize: 11,
                                color: _summaryWords > 200 ? AppColors.critical : AppColors.muted)),
                        const SizedBox(width: 8),
                        _micButton('summary', _summaryCtrl),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      TextFormField(
                        controller: _summaryCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: _listeningField == 'summary'
                              ? '🎤 Listening…'
                              : 'Brief clinical summary…',
                          hintStyle: GoogleFonts.dmSans(
                              color: _listeningField == 'summary'
                                  ? AppColors.critical
                                  : AppColors.muted.withOpacity(0.6),
                              fontSize: 13),
                          filled: true,
                          fillColor: _listeningField == 'summary'
                              ? AppColors.redLight
                              : AppColors.bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: _listeningField == 'summary'
                                  ? BorderSide(color: AppColors.critical.withOpacity(0.5))
                                  : BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: _listeningField == 'summary'
                                  ? BorderSide(color: AppColors.critical.withOpacity(0.5))
                                  : BorderSide.none),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (v) => _summaryWords > 200 ? 'Max 200 words' : null,
                      ),
                    ],
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 20),
            _SectionHeader('Risk Assessment'),
            _buildCard([
              // ── Gauge header ──────────────────────────────────────────
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Risk Score',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('Updates live as you fill the form',
                    style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
              ]),
              const SizedBox(height: 16),

              // ── Big percentage + animated bar ─────────────────────────
              _RiskGauge(percent: _riskPercent, level: _suggestedRisk),

              const SizedBox(height: 16),

              // ── Zone labels ───────────────────────────────────────────
              Row(children: [
                _ZoneLabel('0–39%', 'SAFE', const Color(0xFF059669)),
                const SizedBox(width: 6),
                _ZoneLabel('40–69%', 'MODERATE', const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _ZoneLabel('70–100%', 'CRITICAL', const Color(0xFFDC2626)),
              ]),

              const Divider(height: 28),

              // ── Manual override ───────────────────────────────────────
              Row(children: [
                const Icon(Icons.tune_rounded, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Text('Override AI suggestion',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
              ]),
              const SizedBox(height: 10),
              Row(
                children: ['safe', 'moderate', 'critical'].map((r) {
                  final selected = _riskLevel == r;
                  final color = AppTheme.riskColor(r);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setState(() => _riskLevel = r),
                        child: AnimatedContainer(
                          duration: 200.ms,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.riskBgColor(r) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: selected ? color : const Color(0xFFE5E7EB),
                                width: selected ? 2 : 1),
                          ),
                          child: Text(
                            '${AppTheme.riskEmoji(r)} ${r[0].toUpperCase()}${r.substring(1)}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: selected ? color : AppColors.muted),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_riskLevel != _suggestedRisk) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.yellowLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.edit_rounded, size: 13, color: AppColors.warn),
                    const SizedBox(width: 6),
                    Text('Manually overridden from $_suggestedRisk → $_riskLevel',
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: AppColors.warn, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),

            // ★ File Attachments Section
            const SizedBox(height: 20),
            _SectionHeader('Attachments (optional)'),
            _buildCard([
              // Existing attachments
              if (_attachments.isNotEmpty) ...[
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _attachments.asMap().entries.map((e) {
                    final idx = e.key;
                    final att = e.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          att.isImage ? Icons.image_rounded : Icons.attach_file_rounded,
                          size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(att.fileName,
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text('(${att.sizeLabel})',
                            style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _attachments.removeAt(idx)),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: AppColors.primary),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],

              // Add file button
              OutlinedButton.icon(
                onPressed: _pickingFile ? null : _pickFile,
                icon: _pickingFile
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(_pickingFile ? 'Picking files…' : 'Attach File (gallery / documents)',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 4),
              Text('Supports images, PDFs, documents up to 10MB each',
                  style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
            ]),

            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.qr_code_rounded, color: Colors.white),
              label: Text('Generate Transfer QR',
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.expand((w) => [w, const SizedBox(height: 12)]).toList()
          ..removeLast(),
      ),
    );
  }

  // ── Plain field (no mic) ─────────────────────────────────────────────────
  Widget _field(String label, TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? hint,
    bool filled = false,
    Color? fillColor,
    Color? textColor,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.dmSans(
              fontSize: 14,
              color: textColor ?? AppColors.dark,
              fontWeight: textColor != null ? FontWeight.w600 : FontWeight.normal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(
                color: AppColors.muted.withOpacity(0.6), fontSize: 13),
            filled: true,
            fillColor: fillColor ?? AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: filled
                  ? BorderSide(color: AppColors.critical.withOpacity(0.4))
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: filled
                  ? BorderSide(color: AppColors.critical.withOpacity(0.4))
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: filled ? AppColors.critical : AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.critical),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // ── Field WITH mic button ────────────────────────────────────────────────
  Widget _voiceField(String label, TextEditingController ctrl, String fieldKey, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isActive = _listeningField == fieldKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
            _micButton(fieldKey, ctrl),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
          decoration: InputDecoration(
            hintText: isActive ? '🎤 Listening… speak now' : null,
            hintStyle: GoogleFonts.dmSans(
                color: AppColors.critical, fontSize: 13, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: isActive ? AppColors.redLight : AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isActive
                  ? BorderSide(color: AppColors.critical.withOpacity(0.5))
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isActive
                  ? BorderSide(color: AppColors.critical.withOpacity(0.5))
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isActive ? AppColors.critical : AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.critical),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // ── Mic button (animated pulse when active) ──────────────────────────────
  Widget _micButton(String fieldKey, TextEditingController ctrl) {
    final isActive = _listeningField == fieldKey;
    return GestureDetector(
      onTap: () => _toggleListen(fieldKey, ctrl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.critical : AppColors.blueLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [BoxShadow(color: AppColors.critical.withOpacity(0.35), blurRadius: 8, spreadRadius: 1)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.stop_rounded : Icons.mic_rounded,
              size: 14,
              color: isActive ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? 'Stop' : 'Dictate',
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.primary),
            ),
          ],
        ),
      ).animate(target: isActive ? 1 : 0)
          .scaleXY(end: 1.05, duration: 600.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(end: 1.0, duration: 600.ms, curve: Curves.easeInOut),
    );
  }

  Widget _genderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender',
            style: GoogleFonts.dmSans(
                fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
          items: ['Male', 'Female', 'Other']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v!),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title.toUpperCase(),
          style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.muted, letterSpacing: 1.5)),
    );
  }
}

// ── Animated risk gauge ─────────────────────────────────────────────────────
class _RiskGauge extends StatelessWidget {
  final int percent;   // 0–100
  final String level;  // safe | moderate | critical

  const _RiskGauge({required this.percent, required this.level});

  Color get _barColor {
    if (percent >= 70) return const Color(0xFFDC2626);
    if (percent >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFF059669);
  }

  Color get _bgColor {
    if (percent >= 70) return const Color(0xFFFEE2E2);
    if (percent >= 40) return const Color(0xFFFEF3C7);
    return const Color(0xFFD1FAE5);
  }

  String get _label {
    if (percent >= 70) return 'HIGH RISK — Urgent transfer';
    if (percent >= 40) return 'MODERATE — Monitor closely';
    return 'LOW RISK — Stable for transfer';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big number + label row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: percent),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => Text(
                '$val%',
                style: GoogleFonts.dmSans(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: _barColor,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _barColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      level.toUpperCase(),
                      style: GoogleFonts.dmSans(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_label,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Gradient track
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: const Color(0xFFF3F4F6),
                  ),
                  // Filled portion with gradient
                  FractionallySizedBox(
                    widthFactor: val,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: percent >= 70
                              ? [const Color(0xFFF59E0B), const Color(0xFFDC2626)]
                              : percent >= 40
                                  ? [const Color(0xFF10B981), const Color(0xFFF59E0B)]
                                  : [const Color(0xFF34D399), const Color(0xFF10B981)],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Tick marks under bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['0', '20', '40', '60', '80', '100'].map((t) =>
            Text(t, style: GoogleFonts.spaceMono(fontSize: 9, color: AppColors.muted))
          ).toList(),
        ),
      ],
    );
  }
}

// ── Zone label chip ─────────────────────────────────────────────────────────
class _ZoneLabel extends StatelessWidget {
  final String range;
  final String label;
  final Color color;
  const _ZoneLabel(this.range, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: color, letterSpacing: 0.8)),
          Text(range,
              style: GoogleFonts.dmSans(fontSize: 9, color: color.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}
