import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../models/auth_models.dart';
import '../../services/transfer_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/qr_modal.dart';
import 'transfer_timeline_screen.dart';
import 'transfer_detail_screen.dart';
import '../role_selection_screen.dart';
import '../../widgets/emergency_card.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  List<PatientTransfer> _transfers = [];
  bool _loading = true;
  PatientProfile? _patient;
  PatientTransfer? _latest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Load patient profile
    final patient = await AuthService.getCurrentPatient();
    // Load transfers by phone number (Firestore sync)
    final phone = patient?.phone ?? await AuthService.getCurrentPatientPhone() ?? '';
    final all = await TransferService.getPatientTransfers(phone);
    if (mounted) {
      setState(() {
        _patient = patient;
        _transfers = all;
        _latest = all.isNotEmpty ? all.first : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🚨 SOS Floating Action Button
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => EmergencyCard.show(
                context,
                patientName: _latest?.patientName ?? _patient?.name ?? 'Patient',
                patientId: _patient?.patientId ?? _latest?.patientId ?? '',
                allergies: _latest?.allergies ?? '',
                medications: _latest?.medications ?? '',
                bloodGroup: _patient?.bloodGroup ?? '',
                emergencyContact: _patient?.emergencyContact ?? '',
                latestTransfer: _latest,
              ),
              backgroundColor: const Color(0xFFDC2626),
              icon: const Icon(Icons.emergency_rounded, color: Colors.white),
              label: Text('SOS Card',
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700, color: Colors.white)),
              elevation: 6,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
            else ...[
              SliverToBoxAdapter(child: _buildStatusCard()),
              SliverToBoxAdapter(child: _buildQuickCards(context)),
              if (_transfers.isNotEmpty)
                SliverToBoxAdapter(child: _buildRecentTransfers(context)),
              SliverToBoxAdapter(child: _buildAllergiesCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
          child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
        ),
        onPressed: () async {
          await AuthService.logoutPatient();
          if (mounted) {
            Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (r) => false);
          }
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: AppColors.greenLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.person_rounded, size: 20, color: AppColors.accent),
          ),
        ),
      ],
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello,', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
            Text(_patient?.name ?? _latest?.patientName ?? 'Patient',
                style: GoogleFonts.dmSans(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isStable = _latest == null || _latest!.riskLevel == 'safe';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF047857)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.favorite_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text('CURRENT STATUS',
                style: GoogleFonts.dmSans(
                    fontSize: 10, color: Colors.white70,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 10),
          Text(isStable ? 'Stable' : 'Under Monitoring',
              style: GoogleFonts.dmSans(
                  fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(_latest != null ? 'Post-transfer recovery' : 'No active transfers',
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70)),
          if (_patient != null) ...[
            const SizedBox(height: 10),
            Text('ID: ${_patient!.patientId}',
                style: GoogleFonts.spaceMono(fontSize: 12, color: Colors.white60)),
          ],
          if (_latest != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              _StatusChip(_latest!.vitals.bp, 'BP'),
              const SizedBox(width: 8),
              _StatusChip(_latest!.vitals.pulse, 'Pulse'),
              const SizedBox(width: 8),
              _StatusChip('${_latest!.vitals.temp}°', 'Temp'),
            ]),
          ],
        ]),
      ).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),
    );
  }

  Widget _buildQuickCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(children: [
        _QuickCard(
          icon: Icons.timeline_rounded,
          iconBg: AppColors.blueLight,
          iconColor: AppColors.primary,
          title: 'Medical Journey',
          subtitle: '${_transfers.length} transfer${_transfers.length != 1 ? 's' : ''} recorded',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => TransferTimelineScreen(transfers: _transfers))),
        ),
        const SizedBox(height: 12),
        _QuickCard(
          icon: Icons.shield_rounded,
          iconBg: AppColors.blueLight,
          iconColor: AppColors.primary,
          title: 'Access Transparency',
          subtitle: 'See who viewed your records',
          onTap: () => _showAccessLog(context),
        ),
      ]).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildRecentTransfers(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT TRANSFERS',
              style: GoogleFonts.dmSans(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          ..._transfers.take(3).map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TransferDetailScreen(transfer: t))),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: AppTheme.riskColor(t.riskLevel), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.sendingHospital,
                            style: GoogleFonts.dmSans(
                                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
                        Text('${t.sendingDoctor} • ${_formatTime(t.createdAt)}',
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                      ],
                    )),
                    // ★ Inline QR code — tap to expand
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
                          size: 64,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.L,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          )),
        ],
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  Widget _buildAllergiesCard() {
    if (_latest == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.redLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.critical.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⚠ ALLERGIES',
                style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.critical, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(_latest!.allergies,
                style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.critical)),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CURRENT MEDICATIONS',
                style: GoogleFonts.dmSans(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(_latest!.medications,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark)),
          ]),
        ),
      ]).animate().fadeIn(delay: 350.ms),
    );
  }

  void _showAccessLog(BuildContext context) {
    final allLogs = _transfers.expand((t) => t.accessLogs).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const Icon(Icons.shield_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Access Transparency',
                  style: GoogleFonts.dmSans(
                      fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.dark)),
            ]),
          ),
          Expanded(
            child: allLogs.isEmpty
                ? Center(
                    child: Text('No access logs yet',
                        style: GoogleFonts.dmSans(color: AppColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: allLogs.length,
                    itemBuilder: (_, i) {
                      final log = allLogs[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: log.action == 'reviewed'
                                  ? AppColors.accent
                                  : log.action == 'flagged'
                                      ? AppColors.warn
                                      : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.doctorName,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppColors.dark)),
                              Text('${log.hospital} • ${log.action}',
                                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                            ],
                          )),
                          Text(_formatTime(log.timestamp),
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatusChip(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value.isEmpty ? '—' : value,
              style: GoogleFonts.spaceMono(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white60)),
        ]),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                Text(subtitle,
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 24),
          ]),
        ),
      ),
    );
  }
}
