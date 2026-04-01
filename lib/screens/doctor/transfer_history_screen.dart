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
import 'review_screen.dart';
import 'create_transfer_screen.dart';

class TransferHistoryScreen extends StatefulWidget {
  const TransferHistoryScreen({super.key});

  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  List<PatientTransfer> _all = [];
  List<PatientTransfer> _filtered = [];
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await AuthService.getCurrentDoctor();
    final data = await TransferService.getByDoctor(doc?.phone ?? '');
    if (mounted) {
      setState(() {
        _all = data;
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    if (_filter == 'all') {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((t) => t.riskLevel == _filter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
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
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateTransferScreen())).then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'critical', 'moderate', 'safe'].map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(f == 'all' ? 'All' : f.toUpperCase(),
                          style: GoogleFonts.dmSans(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: selected
                                  ? (f == 'all' ? AppColors.primary : AppTheme.riskColor(f))
                                  : AppColors.muted)),
                      selectedColor: f == 'all'
                          ? AppColors.blueLight
                          : AppTheme.riskBgColor(f),
                      backgroundColor: Colors.white,
                      checkmarkColor: f == 'all' ? AppColors.primary : AppTheme.riskColor(f),
                      side: BorderSide(
                          color: selected
                              ? (f == 'all' ? AppColors.primary : AppTheme.riskColor(f))
                              : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) => setState(() {
                        _filter = f;
                        _applyFilter();
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_open_rounded, size: 48, color: AppColors.muted),
                                const SizedBox(height: 12),
                                Text('No transfers found',
                                    style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) =>
                                _buildTile(_filtered[i], ctx, i).animate().fadeIn(delay: (i * 50).ms),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(PatientTransfer t, BuildContext context, int index) {
    final date = DateFormat('dd MMM • HH:mm').format(t.createdAt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReviewScreen(transfer: t))).then((_) => _load()),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
          ),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                    color: AppTheme.riskColor(t.riskLevel), shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(t.patientName,
                          style: GoogleFonts.dmSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      if (t.isReviewed) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.accent),
                      ],
                      if (t.isFlagged) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.flag_rounded, size: 14, color: AppColors.warn),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(t.diagnosis.length > 30
                        ? '${t.diagnosis.substring(0, 30)}…'
                        : t.diagnosis,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.business_rounded, size: 12, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(t.sendingHospital,
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                    ]),
                    Text(date, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniRiskBadge(score: t.riskScore, level: t.riskLevel),
                  const SizedBox(height: 8),
                  // ★ Inline QR code — tap to expand full modal
                  GestureDetector(
                    onTap: () => QrModal.show(context, t),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: QrImageView(
                        data: t.viewerUrl,
                        version: QrVersions.auto,
                        size: 72,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact risk badge (score + mini bar + label) ───────────────────────────
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
        // Score number
        Text(
          '$score%',
          style: GoogleFonts.dmSans(
              fontSize: 18, fontWeight: FontWeight.w800, color: _color, height: 1),
        ),
        const SizedBox(height: 4),
        // Mini progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 72,
            height: 5,
            child: Stack(
              children: [
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Level chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
          child: Text(
            level.toUpperCase(),
            style: GoogleFonts.dmSans(
                fontSize: 9, fontWeight: FontWeight.w800, color: _color, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}
