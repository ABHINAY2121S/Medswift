import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../services/transfer_service.dart';

class ReviewScreen extends StatefulWidget {
  final PatientTransfer transfer;
  const ReviewScreen({super.key, required this.transfer});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late PatientTransfer _t;
  bool _showNoteField = false;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _t = widget.transfer;
    _noteCtrl.text = _t.arrivalNote ?? '';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _acknowledge() async {
    setState(() => _saving = true);
    _t.isReviewed = true;
    _t.status = 'received';
    _t.accessLogs.add(AccessLog(
      doctorName: 'Dr. Sarah Chen',
      hospital: 'Metro Heart Center',
      timestamp: DateTime.now(),
      action: 'reviewed',
    ));
    await TransferService.save(_t);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer acknowledged. Patient is en route.',
              style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _saveNote() async {
    _t.arrivalNote = _noteCtrl.text.trim();
    _t.accessLogs.add(AccessLog(
      doctorName: 'Dr. Sarah Chen',
      hospital: 'Metro Heart Center',
      timestamp: DateTime.now(),
      action: 'noted',
    ));
    await TransferService.save(_t);
    setState(() => _showNoteField = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Arrival note saved', style: GoogleFonts.dmSans()),
      backgroundColor: AppColors.dark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _flagDiscrepancy() async {
    _t.isFlagged = true;
    _t.accessLogs.add(AccessLog(
      doctorName: 'Dr. Sarah Chen',
      hospital: 'Metro Heart Center',
      timestamp: DateTime.now(),
      action: 'flagged',
    ));
    await TransferService.save(_t);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Discrepancy flagged and logged', style: GoogleFonts.dmSans()),
      backgroundColor: AppColors.warn,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.riskColor(_t.riskLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Review'),
        leading: IconButton(
          icon: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.dark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.redLight, borderRadius: BorderRadius.circular(20)),
            child: Text('INCOMING',
                style: GoogleFonts.dmSans(
                    fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.critical)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 90-second snapshot
          _buildSnapshotCard(riskColor).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),

          const SizedBox(height: 20),
          Text('FULL TRANSFER DETAILS',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1.5)),
          const SizedBox(height: 12),

          _InfoCard('Diagnosis', _t.diagnosis),
          _InfoCard('Transfer Reason', _t.transferReason),
          if (_t.clinicalSummary.isNotEmpty)
            _InfoCard('Clinical Summary', _t.clinicalSummary),
          _buildReferringCard(),
          _buildVitalsCard(),

          const SizedBox(height: 20),
          Text('ACCESS LOG',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _buildAccessLog(),

          const SizedBox(height: 20),

          // Actions
          if (!_t.isReviewed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _acknowledge,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: Text('Acknowledge & Accept',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.verified_rounded, color: AppColors.accent),
                const SizedBox(width: 10),
                Text('Transfer Acknowledged',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600, color: AppColors.accent)),
              ]),
            ),

          const SizedBox(height: 12),

          // Add Arrival Note
          OutlinedButton.icon(
            onPressed: () => setState(() => _showNoteField = !_showNoteField),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text('Add Arrival Note',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dark,
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),

          if (_showNoteField) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter arrival note...',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.muted),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.bg,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveNote,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text('Save Note',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),
          ],

          const SizedBox(height: 12),

          // Flag Discrepancy
          if (!_t.isFlagged)
            OutlinedButton.icon(
              onPressed: _flagDiscrepancy,
              icon: const Icon(Icons.flag_rounded, size: 18, color: AppColors.warn),
              label: Text('Flag Discrepancy',
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600, color: AppColors.warn)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.warn.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.yellowLight,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.flag_rounded, color: AppColors.warn, size: 16),
                const SizedBox(width: 8),
                Text('Discrepancy flagged',
                    style: GoogleFonts.dmSans(color: AppColors.warn, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(Color riskColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _t.riskLevel == 'critical'
              ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
              : _t.riskLevel == 'moderate'
                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                  : [const Color(0xFF059669), const Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: riskColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bolt_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text('90-SECOND SNAPSHOT',
                style: GoogleFonts.dmSans(
                    fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t.patientName,
                        style: GoogleFonts.dmSans(
                            fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${_t.patientAge}${_t.patientGender[0]} • ID: ${_t.patientId}',
                        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(AppTheme.riskEmoji(_t.riskLevel), style: const TextStyle(fontSize: 20)),
                  Text(_t.riskLevel.toUpperCase(),
                      style: GoogleFonts.dmSans(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Vitals
          Row(children: [
            _VitalChip('BP', _t.vitals.bp),
            const SizedBox(width: 8),
            _VitalChip('PULSE', _t.vitals.pulse),
            const SizedBox(width: 8),
            _VitalChip('TEMP', '${_t.vitals.temp}°'),
            if (_t.vitals.spo2.isNotEmpty) ...[
              const SizedBox(width: 8),
              _VitalChip('SPO2', _t.vitals.spo2),
            ],
          ]),
          const SizedBox(height: 12),
          // Allergies
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠ ALLERGIES',
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(_t.allergies,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KEY MEDICATIONS',
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(_t.medications,
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferringCard() {
    return _buildInfoContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REFERRING DOCTOR',
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.business_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t.sendingHospital,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                Text(_t.sendingDoctor,
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildVitalsCard() {
    return _buildInfoContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VITALS',
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _VitalBox('BP', _t.vitals.bp)),
            const SizedBox(width: 8),
            Expanded(child: _VitalBox('Pulse', _t.vitals.pulse)),
            const SizedBox(width: 8),
            Expanded(child: _VitalBox('Temp', '${_t.vitals.temp}°')),
            if (_t.vitals.spo2.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(child: _VitalBox('SpO2', _t.vitals.spo2)),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildAccessLog() {
    return _buildInfoContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _t.accessLogs.isEmpty
            ? [Text('No access logs', style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13))]
            : _t.accessLogs.reversed.take(5).map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: log.action == 'flagged' ? AppColors.warn
                              : log.action == 'reviewed' ? AppColors.accent
                              : AppColors.primary,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${log.doctorName} • ${log.action}',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.dark)),
                          Text(log.hospital,
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Text(_formatTime(log.timestamp),
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                  ]),
                )).toList(),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildInfoContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: child,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark)),
        ],
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final String value;
  const _VitalChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.spaceMono(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white60)),
        ]),
      ),
    );
  }
}

class _VitalBox extends StatelessWidget {
  final String label;
  final String value;
  const _VitalBox(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value.isEmpty ? '—' : value,
            style: GoogleFonts.spaceMono(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
      ]),
    );
  }
}
