import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../models/transfer.dart';

/// Reusable QR modal — call [QrModal.show] from any screen.
class QrModal {
  static void show(BuildContext context, PatientTransfer transfer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrSheet(transfer: transfer),
    );
  }
}

class _QrSheet extends StatelessWidget {
  final PatientTransfer transfer;
  const _QrSheet({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.riskColor(transfer.riskLevel);

    return Container(
      padding: const EdgeInsets.only(bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(transfer.patientName,
                            style: GoogleFonts.dmSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark)),
                        Text('Transfer ID: ${transfer.id}',
                            style: GoogleFonts.dmSans(
                                fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  _MiniRiskBadge(score: transfer.riskScore, level: transfer.riskLevel),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // QR Code
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: QrImageView(
                data: transfer.viewerUrl,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 16),

            Text('Scan to view full patient record',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      transfer.viewerUrl,
                      style: GoogleFonts.spaceMono(
                          fontSize: 9,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // Info row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _InfoChip(
                      Icons.local_hospital_rounded, transfer.sendingHospital),
                  const SizedBox(width: 8),
                  _InfoChip(Icons.person_rounded, transfer.sendingDoctor),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Close',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.dark,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact risk badge ────────────────────────────────────────────────────────
class _MiniRiskBadge extends StatelessWidget {
  final int score;
  final String level;
  const _MiniRiskBadge({required this.score, required this.level});

  Color get _color {
    if (score >= 70) return const Color(0xFFDC2626);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFF059669);
  }

  Color get _bg {
    if (score >= 70) return const Color(0xFFFEE2E2);
    if (score >= 40) return const Color(0xFFFEF3C7);
    return const Color(0xFFD1FAE5);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$score%',
            style: GoogleFonts.dmSans(
                fontSize: 18, fontWeight: FontWeight.w800, color: _color, height: 1)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 72, height: 5,
            child: Stack(children: [
              Container(color: const Color(0xFFF3F4F6)),
              FractionallySizedBox(
                widthFactor: (score / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: score >= 70
                          ? [const Color(0xFFF59E0B), const Color(0xFFDC2626)]
                          : score >= 40
                              ? [const Color(0xFF10B981), const Color(0xFFF59E0B)]
                              : [const Color(0xFF34D399), const Color(0xFF10B981)],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
          child: Text(level.toUpperCase(),
              style: GoogleFonts.dmSans(
                  fontSize: 9, fontWeight: FontWeight.w800, color: _color, letterSpacing: 0.5)),
        ),
      ],
    );
  }
}
