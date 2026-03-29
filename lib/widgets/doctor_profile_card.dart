import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/recommendation_service.dart';

class DoctorProfileCard extends StatelessWidget {
  final DoctorRecommendation rec;

  const DoctorProfileCard({super.key, required this.rec});

  static void show(BuildContext context, DoctorRecommendation rec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DoctorProfileCard(rec: rec),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = rec.doctor;
    final rating = rec.starRating;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Avatar + name
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 4))
              ],
            ),
            child: Center(
              child: Text(
                doc.name.isNotEmpty ? doc.name[0].toUpperCase() : 'D',
                style: GoogleFonts.dmSans(
                    fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text('Dr. ${doc.name}',
              style: GoogleFonts.dmSans(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 4),

          // Speciality badge
          if (doc.speciality.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(doc.speciality,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          const SizedBox(height: 8),

          Text(doc.hospitalName,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),

          const SizedBox(height: 20),

          // Star rating row
          _StarRatingRow(rating: rating, total: doc.totalTransfers),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            _StatBadge(
              icon: Icons.swap_horiz_rounded,
              label: 'Total Transfers',
              value: '${doc.totalTransfers}',
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            _StatBadge(
              icon: Icons.check_circle_rounded,
              label: 'Completed',
              value: '${doc.completedTransfers}',
              color: AppColors.accent,
            ),
            const SizedBox(width: 12),
            _StatBadge(
              icon: Icons.percent_rounded,
              label: 'Success Rate',
              value: doc.totalTransfers == 0
                  ? 'New'
                  : '${((doc.completedTransfers / doc.totalTransfers) * 100).toStringAsFixed(0)}%',
              color: const Color(0xFF6366F1),
            ),
          ]),

          const SizedBox(height: 16),

          // Match reason chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(rec.matchReason,
                    style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Close button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Close',
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700, color: AppColors.dark)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Star rating row ──────────────────────────────────────────────────────────
class _StarRatingRow extends StatelessWidget {
  final double rating;
  final int total;
  const _StarRatingRow({required this.rating, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final filled = i < rating.floor();
          final half = !filled && i < rating;
          return Icon(
            half ? Icons.star_half_rounded : (filled ? Icons.star_rounded : Icons.star_border_rounded),
            color: const Color(0xFFFBBF24),
            size: 32,
          );
        }),
      ),
      const SizedBox(height: 4),
      Text(
        total == 0
            ? 'New doctor — no transfers yet'
            : '${rating.toStringAsFixed(1)} ★  •  $total transfers',
        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
      ),
    ]);
  }
}

// ── Stat badge ───────────────────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatBadge({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.muted)),
        ]),
      ),
    );
  }
}
