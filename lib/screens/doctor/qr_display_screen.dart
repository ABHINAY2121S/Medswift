import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import 'doctor_dashboard_screen.dart';

class QrDisplayScreen extends StatelessWidget {
  final PatientTransfer transfer;
  const QrDisplayScreen({super.key, required this.transfer});

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.riskColor(transfer.riskLevel);
    final qrData = transfer.viewerUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer QR'),
        leading: IconButton(
          icon: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.dark),
          ),
          onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
              (r) => false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Patient info + QR
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(transfer.patientName,
                                style: GoogleFonts.dmSans(
                                    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
                            Text('ID: ${transfer.patientId}',
                                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppTheme.riskBgColor(transfer.riskLevel),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(transfer.riskLevel.toUpperCase(),
                            style: GoogleFonts.dmSans(
                                fontSize: 11, fontWeight: FontWeight.w700, color: riskColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(transfer.diagnosis,
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 20),
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Scan to access full patient transfer record',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                      textAlign: TextAlign.center),
                ],
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 20),

            // Short link
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(transfer.shortLink,
                        style: GoogleFonts.spaceMono(
                            fontSize: 12, color: AppColors.dark, fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: qrData));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Link copied!',
                              style: GoogleFonts.dmSans()),
                          backgroundColor: AppColors.dark,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('Copy',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 12),

            // Share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Share.share(
                  '🏥 MedSwift Patient Transfer\n\nPatient: ${transfer.patientName}\nDiagnosis: ${transfer.diagnosis}\n\nAccess record: $qrData',
                  subject: 'Patient Transfer — ${transfer.patientName}',
                ),
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                label: Text('Share Transfer Link',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 12),

            // Critical info reminder
            if (transfer.riskLevel == 'critical')
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.critical.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.critical, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CRITICAL TRANSFER — Allergies: ${transfer.allergies}',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppColors.critical, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
