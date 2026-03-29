import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../widgets/qr_modal.dart';
import '../../services/transfer_service.dart';
import '../../widgets/transfer_status_tracker.dart';

class TransferDetailScreen extends StatefulWidget {
  final PatientTransfer transfer;
  const TransferDetailScreen({super.key, required this.transfer});

  @override
  State<TransferDetailScreen> createState() => _TransferDetailScreenState();
}

class _TransferDetailScreenState extends State<TransferDetailScreen> {
  late PatientTransfer transfer;
  StreamSubscription<PatientTransfer?>? _sub;

  @override
  void initState() {
    super.initState();
    transfer = widget.transfer;
    // Subscribe to Firestore real-time updates
    _sub = TransferService.stream(transfer.id).listen((updated) {
      if (updated != null && mounted) {
        setState(() => transfer = updated);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.riskColor(transfer.riskLevel);
    final date = DateFormat('MMMM dd, yyyy • HH:mm').format(transfer.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Details'),
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
          // ★ QR button in app bar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Show QR Code',
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.blueLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.qr_code_rounded, color: AppColors.primary, size: 20),
              ),
              onPressed: () => QrModal.show(context, transfer),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text('READ ONLY',
                  style: GoogleFonts.dmSans(
                      fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.muted)),
              backgroundColor: AppColors.bg,
              side: BorderSide(color: AppColors.border),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      // ★ FAB for QR too
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => QrModal.show(context, transfer),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
        label: Text('Show QR',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor, riskColor.withOpacity(0.8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: riskColor.withOpacity(0.3), blurRadius: 16)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(transfer.sendingHospital,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${transfer.riskScore}% ${transfer.riskLevel.toUpperCase()}',
                      style: GoogleFonts.dmSans(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(date, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70)),
            ]),
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          // ★ Real-time status tracker
          TransferStatusTracker(transfer: transfer).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 4),
          _DetailCard(
            title: 'Attending Physician',
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: AppColors.blueLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(transfer.sendingDoctor,
                    style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                Text(transfer.sendingHospital,
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
              ]),
            ]),
          ),

          if (transfer.receivingHospital.isNotEmpty)
            _DetailCard(
              title: 'Transfer Path',
              child: Row(children: [
                Expanded(child: _HospitalBox(transfer.sendingHospital, 'Sending')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                ),
                Expanded(child: _HospitalBox(transfer.receivingHospital, 'Receiving')),
              ]),
            ),

          // Critical info
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.critical.withOpacity(0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('⚠ ALLERGIES FLAGGED',
                  style: GoogleFonts.dmSans(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.critical, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(transfer.allergies,
                  style: GoogleFonts.dmSans(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.critical)),
            ]),
          ),

          _DetailCard(
            title: 'Vitals at Transfer',
            child: Row(children: [
              Expanded(child: _VBox(transfer.vitals.bp, 'BP')),
              const SizedBox(width: 8),
              Expanded(child: _VBox(transfer.vitals.pulse, 'Pulse')),
              const SizedBox(width: 8),
              Expanded(child: _VBox('${transfer.vitals.temp}°', 'Temp')),
              if (transfer.vitals.spo2.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(child: _VBox(transfer.vitals.spo2, 'SpO2')),
              ],
            ]),
          ),

          _DetailCard(
            title: 'Diagnosis',
            child: Text(transfer.diagnosis,
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: AppColors.dark, fontWeight: FontWeight.w500)),
          ),

          _DetailCard(
            title: 'Medications',
            child: Text(transfer.medications,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark)),
          ),

          _DetailCard(
            title: 'Reason for Transfer',
            child: Text(transfer.transferReason,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark, height: 1.5)),
          ),

          if (transfer.clinicalSummary.isNotEmpty)
            _DetailCard(
              title: "Doctor's Note",
              child: Text(transfer.clinicalSummary,
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark, height: 1.6)),
            ),

          if (transfer.arrivalNote != null && transfer.arrivalNote!.isNotEmpty)
            _DetailCard(
              title: 'Arrival Note (Receiving Doctor)',
              child: Text(transfer.arrivalNote!,
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark, height: 1.5)),
            ),

          _DetailCard(
            title: 'Transfer Status',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _Badge(transfer.status.toUpperCase(), AppColors.primary, AppColors.blueLight),
              if (transfer.isReviewed)
                _Badge('REVIEWED', AppColors.accent, AppColors.greenLight),
              if (transfer.isFlagged)
                _Badge('FLAGGED', AppColors.warn, AppColors.yellowLight),
            ]),
          ),

          // ★ Attachments section
          if (transfer.attachments.isNotEmpty)
            _DetailCard(
              title: 'Attached Files (${transfer.attachments.length})',
              child: Column(
                children: transfer.attachments.map((att) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(
                          att.isImage ? Icons.image_rounded : Icons.description_rounded,
                          color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(att.fileName,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: AppColors.dark),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(att.sizeLabel,
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                        ],
                      )),
                      // Show image preview for images
                      if (att.isImage)
                        GestureDetector(
                          onTap: () => _showImagePreview(context, att),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: AppColors.greenLight,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('View',
                                style: GoogleFonts.dmSans(
                                    fontSize: 11, color: AppColors.accent,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ]),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.lock_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('This is a read-only view. Contact your doctor to update records.',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, TransferAttachment att) {
    final imageBytes = base64Decode(att.base64Data);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(att.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Flexible(
            child: InteractiveViewer(child: Image.memory(imageBytes, fit: BoxFit.contain)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: GoogleFonts.dmSans(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class _HospitalBox extends StatelessWidget {
  final String name;
  final String label;
  const _HospitalBox(this.name, this.label);
  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(name, textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.dark)),
        ]),
      );
}

class _VBox extends StatelessWidget {
  final String value;
  final String label;
  const _VBox(this.value, this.label);
  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value.isEmpty ? '—' : value,
              style: GoogleFonts.spaceMono(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Badge(this.label, this.color, this.bg);
  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}
