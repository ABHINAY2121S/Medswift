import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../services/transfer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/qr_modal.dart';
import 'transfer_detail_screen.dart';

/// Medical Journey screen — fetches its OWN data from Firestore so it always
/// shows the latest transfers regardless of what the dashboard had loaded.
class TransferTimelineScreen extends StatefulWidget {
  /// Optional pre-loaded list (used as initial data while fetching)
  final List<PatientTransfer> transfers;
  const TransferTimelineScreen({super.key, this.transfers = const []});

  @override
  State<TransferTimelineScreen> createState() => _TransferTimelineScreenState();
}

class _TransferTimelineScreenState extends State<TransferTimelineScreen> {
  List<PatientTransfer> _transfers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Show pre-loaded data instantly, then refresh from Firestore
    _transfers = List.from(widget.transfers);
    if (_transfers.isNotEmpty) _loading = false;
    _load();
  }

  Future<void> _load() async {
    final phone = await AuthService.getCurrentPatientPhone() ?? '';
    if (phone.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final data = await TransferService.getPatientTransfers(phone);
    if (mounted) {
      setState(() {
        _transfers = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Journey'),
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
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: _transfers.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timeline_rounded, size: 56, color: AppColors.muted),
                              const SizedBox(height: 12),
                              Text('No transfer history yet',
                                  style: GoogleFonts.dmSans(
                                      color: AppColors.muted, fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('Pull down to refresh',
                                  style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        // Summary badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Text('${_transfers.length} transfer${_transfers.length != 1 ? 's' : ''} recorded in your history',
                                style: GoogleFonts.dmSans(
                                    fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                          ]),
                        ).animate().fadeIn(),

                        // Timeline entries
                        ..._transfers.asMap().entries.map((entry) {
                          final i = entry.key;
                          final t = entry.value;
                          final isLast = i == _transfers.length - 1;
                          return _TimelineEntry(
                            transfer: t,
                            isLast: isLast,
                            index: i,
                          );
                        }),
                      ],
                    ),
            ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final PatientTransfer transfer;
  final bool isLast;
  final int index;

  const _TimelineEntry({
    required this.transfer,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.riskColor(transfer.riskLevel);
    final riskBg = AppTheme.riskBgColor(transfer.riskLevel);
    final date = DateFormat('dd MMM yyyy • HH:mm').format(transfer.createdAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline spine
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: riskColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: riskBg, width: 4),
                    boxShadow: [BoxShadow(color: riskColor.withOpacity(0.3), blurRadius: 6)],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
                if (isLast) const SizedBox(height: 24),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => TransferDetailScreen(transfer: transfer))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 3,
                          child: _MiniRiskInline(score: transfer.riskScore, level: transfer.riskLevel),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          flex: 2,
                          child: Text(
                            date,
                            style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(transfer.sendingHospital,
                        style: GoogleFonts.dmSans(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                    if (transfer.receivingHospital.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('→', style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(transfer.receivingHospital,
                              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 6),
                    Text(transfer.diagnosis.length > 50
                        ? '${transfer.diagnosis.substring(0, 50)}…'
                        : transfer.diagnosis,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.medical_services_rounded, size: 12, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(transfer.sendingDoctor,
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ),
                      if (transfer.isReviewed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.greenLight,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('Reviewed',
                              style: GoogleFonts.dmSans(
                                  fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 6),
                        // ★ Inline QR on every timeline entry — tap to expand
                        GestureDetector(
                          onTap: () => QrModal.show(context, transfer),
                          child: Container(
                            width: 62, height: 62, // 56 size + 6 total padding prevents IntrinsicHeight crash
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: QrImageView(
                              data: transfer.viewerUrl,
                              version: QrVersions.auto,
                              size: 56,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.L,
                            ),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.1),
    );
  }
}

// ── Inline compact risk widget (fits in a row, horizontal bar) ───────────────
class _MiniRiskInline extends StatelessWidget {
  final int score;
  final String level;
  const _MiniRiskInline({required this.score, required this.level});

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
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        Text('$score%',
            style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w800, color: _color, height: 1)),
        const SizedBox(width: 6),
        // Mini bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            width: 48, height: 5,
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
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
          child: Text(level.toUpperCase(),
              style: GoogleFonts.dmSans(
                  fontSize: 8, fontWeight: FontWeight.w800, color: _color, letterSpacing: 0.5)),
        ),
      ],
    ),
    );
  }
}
