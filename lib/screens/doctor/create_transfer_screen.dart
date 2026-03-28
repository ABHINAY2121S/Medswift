import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../services/transfer_service.dart';
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
  final _diagnosisCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medsCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _sendingHospitalCtrl = TextEditingController(text: 'City General Hospital');
  final _receivingHospitalCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController(text: 'Dr. Sarah Chen');

  String _gender = 'Male';
  String _riskLevel = 'moderate';
  String _suggestedRisk = 'moderate';
  List<String> _conflicts = [];
  int _summaryWords = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _allergiesCtrl.addListener(_checkConflicts);
    _medsCtrl.addListener(_checkConflicts);
    _bpCtrl.addListener(_suggestRisk);
    _pulseCtrl.addListener(_suggestRisk);
    _diagnosisCtrl.addListener(_suggestRisk);
    _summaryCtrl.addListener(_updateWordCount);
  }

  void _checkConflicts() {
    final c = TransferService.detectConflicts(_allergiesCtrl.text, _medsCtrl.text);
    setState(() => _conflicts = c);
  }

  void _suggestRisk() {
    final v = Vitals(bp: _bpCtrl.text, pulse: _pulseCtrl.text, temp: _tempCtrl.text);
    final r = TransferService.suggestRisk(v, _diagnosisCtrl.text);
    setState(() {
      _suggestedRisk = r;
      // Auto-select suggested risk if user hasn't manually changed
      _riskLevel = r;
    });
  }

  void _updateWordCount() {
    final words = _summaryCtrl.text.trim().split(RegExp(r'\s+'));
    setState(() => _summaryWords = _summaryCtrl.text.isEmpty ? 0 : words.length);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _ageCtrl, _diagnosisCtrl, _allergiesCtrl, _medsCtrl,
        _bpCtrl, _pulseCtrl, _tempCtrl, _spo2Ctrl, _reasonCtrl, _summaryCtrl,
        _sendingHospitalCtrl, _receivingHospitalCtrl, _doctorCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final transfer = PatientTransfer(
      id: TransferService.generateId(),
      patientName: _nameCtrl.text.trim(),
      patientAge: int.tryParse(_ageCtrl.text) ?? 0,
      patientGender: _gender,
      patientId: TransferService.generatePatientId(),
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
      riskLevel: _riskLevel,
      sendingHospital: _sendingHospitalCtrl.text.trim(),
      sendingDoctor: _doctorCtrl.text.trim(),
      receivingHospital: _receivingHospitalCtrl.text.trim(),
      createdAt: DateTime.now(),
      accessLogs: [
        AccessLog(
          doctorName: _doctorCtrl.text.trim(),
          hospital: _sendingHospitalCtrl.text.trim(),
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
                              fontWeight: FontWeight.w700, color: AppColors.critical, fontSize: 13)),
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
              _field('Sending Hospital', _sendingHospitalCtrl),
              _field('Receiving Hospital (optional)', _receivingHospitalCtrl),
              _field('Doctor Name', _doctorCtrl),
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
                  validator: (v) => v!.isEmpty ? 'Allergies are required (enter None if none)' : null),
              _field('Current Medications *', _medsCtrl,
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
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
              _field('Reason for Transfer *', _reasonCtrl,
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
                      Text('$_summaryWords / 200 words',
                          style: GoogleFonts.dmSans(fontSize: 11, color:
                          _summaryWords > 200 ? AppColors.critical : AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _summaryCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Brief clinical summary…',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.muted.withOpacity(0.6), fontSize: 13),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) => _summaryWords > 200 ? 'Max 200 words' : null,
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 20),
            _SectionHeader('Risk Assessment'),
            _buildCard([
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('AI Suggested: ', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.riskBgColor(_suggestedRisk),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_suggestedRisk.toUpperCase(),
                      style: GoogleFonts.dmSans(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppTheme.riskColor(_suggestedRisk))),
                ),
              ]),
              const SizedBox(height: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? color : AppColors.muted),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ]),

            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.qr_code_rounded, color: Colors.white),
              label: Text('Generate Transfer QR',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
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
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.dmSans(fontSize: 14, color: textColor ?? AppColors.dark, fontWeight: textColor != null ? FontWeight.w600 : FontWeight.normal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: AppColors.muted.withOpacity(0.6), fontSize: 13),
            filled: true,
            fillColor: fillColor ?? AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: filled ? BorderSide(color: AppColors.critical.withOpacity(0.4)) : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: filled ? BorderSide(color: AppColors.critical.withOpacity(0.4)) : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: filled ? AppColors.critical : AppColors.primary, width: 1.5),
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

  Widget _genderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
