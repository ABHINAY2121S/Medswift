import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';

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

class _QrSheet extends StatefulWidget {
  final PatientTransfer transfer;
  const _QrSheet({required this.transfer});

  @override
  State<_QrSheet> createState() => _QrSheetState();
}

class _QrSheetState extends State<_QrSheet> {
  late PatientTransfer _t;
  bool _regenerating = false;

  @override
  void initState() {
    super.initState();
    _t = widget.transfer;
  }

  bool get _isExpired => DateTime.now().isAfter(_t.qrExpiresAt);

  String get _expiryLabel {
    if (_isExpired) return 'EXPIRED';
    final diff = _t.qrExpiresAt.difference(DateTime.now());
    if (diff.inMinutes < 60) return 'Expires in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Expires in ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'Expires ${diff.inDays}d ${diff.inHours % 24}h';
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    await TransferService.regenerateQrAccess(_t.id);
    // Reload fresh from Firestore
    final fresh = await TransferService.getById(_t.id);
    if (fresh != null && mounted) {
      setState(() {
        _t = fresh;
        _regenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.riskColor(_t.riskLevel);

    return Container(
      padding: const EdgeInsets.only(bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                          Text(_t.patientName,
                              style: GoogleFonts.dmSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dark)),
                          Text('Transfer ID: ${_t.id}',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    _MiniRiskBadge(score: _t.riskScore, level: _t.riskLevel),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── PIN SECTION ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isExpired
                          ? [const Color(0xFF6B7280), const Color(0xFF4B5563)]
                          : [const Color(0xFF1A56DB), const Color(0xFF0E9F6E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: (_isExpired ? Colors.grey : AppColors.primary)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Label row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.lock_rounded, color: Colors.white70, size: 13),
                            const SizedBox(width: 5),
                            Text('ACCESS PIN',
                                style: GoogleFonts.dmSans(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: Colors.white70, letterSpacing: 1.5)),
                          ]),
                          // Expiry badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isExpired
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                _isExpired ? Icons.warning_rounded : Icons.timer_rounded,
                                color: _isExpired ? Colors.redAccent : Colors.white70,
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(_expiryLabel,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: _isExpired ? Colors.redAccent : Colors.white70)),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Big PIN digits
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _t.qrPin.split('').map((digit) =>
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 52, height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            alignment: Alignment.center,
                            child: Text(digit,
                                style: GoogleFonts.spaceMono(
                                    fontSize: 28, fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ).toList(),
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'Share this PIN ONLY with the receiving doctor',
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Copy PIN button
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _t.qrPin));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PIN copied: ${_t.qrPin}',
                                  style: GoogleFonts.dmSans()),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text('Copy PIN',
                                style: GoogleFonts.dmSans(
                                    color: Colors.white, fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // QR Code (blurred if expired)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
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
                      child: Opacity(
                        opacity: _isExpired ? 0.2 : 1.0,
                        child: QrImageView(
                          data: _t.viewerUrl,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                    ),
                    if (_isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.critical.withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.lock_rounded, color: AppColors.critical, size: 22),
                          const SizedBox(height: 4),
                          Text('QR EXPIRED', style: GoogleFonts.dmSans(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.critical)),
                        ]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Info chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  _InfoChip(Icons.local_hospital_rounded, _t.sendingHospital),
                  const SizedBox(width: 8),
                  _InfoChip(Icons.person_rounded, _t.sendingDoctor),
                ]),
              ),
              const SizedBox(height: 16),

              // Regenerate button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _regenerating ? null : _regenerate,
                    icon: _regenerating
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                    label: Text(
                      _regenerating ? 'Generating new PIN…' : 'Regenerate QR & New PIN',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

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
