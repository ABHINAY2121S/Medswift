import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';

class TransferDetailScreen extends StatelessWidget {
  final PatientTransfer transfer;
  const TransferDetailScreen({super.key, required this.transfer});

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
      body: ListView(
        padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(transfer.sendingHospital,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(transfer.riskLevel.toUpperCase(),
                          style: GoogleFonts.dmSans(
                              fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(date, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          // Attending physician
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

          // Transfer path
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

          // Vitals on transfer
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
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark, fontWeight: FontWeight.w500)),
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

          // Status badges
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

          const SizedBox(height: 20),

          // Privacy note
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

          const SizedBox(height: 40),
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _HospitalBox extends StatelessWidget {
  final String name;
  final String label;
  const _HospitalBox(this.name, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(name, textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.dark)),
      ]),
    );
  }
}

class _VBox extends StatelessWidget {
  final String value;
  final String label;
  const _VBox(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value.isEmpty ? '—' : value,
            style: GoogleFonts.spaceMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.dark)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Badge(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
