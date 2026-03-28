import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import 'transfer_detail_screen.dart';

class TransferTimelineScreen extends StatelessWidget {
  final List<PatientTransfer> transfers;
  const TransferTimelineScreen({super.key, required this.transfers});

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
      ),
      body: transfers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timeline_rounded, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Text('No transfer history', style: GoogleFonts.dmSans(color: AppColors.muted)),
                ],
              ),
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
                    Text('${transfers.length} transfer${transfers.length != 1 ? 's' : ''} recorded in your history',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                  ]),
                ).animate().fadeIn(),

                // Timeline entries
                ...transfers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  final isLast = i == transfers.length - 1;
                  return _TimelineEntry(
                    transfer: t,
                    isLast: isLast,
                    index: i,
                  );
                }),
              ],
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
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: riskBg, borderRadius: BorderRadius.circular(20)),
                          child: Text(transfer.riskLevel.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                  fontSize: 9, fontWeight: FontWeight.w700, color: riskColor)),
                        ),
                        Text(date, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
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
                        Text(transfer.receivingHospital,
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
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
                      Text(transfer.sendingDoctor,
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      const Spacer(),
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
