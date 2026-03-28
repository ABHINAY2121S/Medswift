import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../models/auth_models.dart';
import '../../services/transfer_service.dart';
import '../../services/auth_service.dart';
import '../../screens/role_selection_screen.dart';
import 'create_transfer_screen.dart';
import 'scan_qr_screen.dart';
import 'transfer_history_screen.dart';
import 'review_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  List<PatientTransfer> _transfers = [];
  bool _loading = true;
  DoctorProfile? _doctor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await TransferService.getAll();
    final doc = await AuthService.getCurrentDoctor();
    if (mounted) setState(() { _transfers = data; _doctor = doc; _loading = false; });
  }

  int get _todayCount {
    final now = DateTime.now();
    return _transfers.where((t) =>
      t.createdAt.year == now.year &&
      t.createdAt.month == now.month &&
      t.createdAt.day == now.day).length;
  }

  int get _criticalPending =>
      _transfers.where((t) => t.riskLevel == 'critical' && !t.isReviewed).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else ...[
              SliverToBoxAdapter(child: _buildStatsRow()),
              SliverToBoxAdapter(child: _buildQuickActions(context)),
              SliverToBoxAdapter(child: _buildRecentHeader()),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildTransferTile(_transfers[i], context),
                  childCount: _transfers.length > 5 ? 5 : _transfers.length,
                ),
              ),
              if (_transfers.length > 5)
                SliverToBoxAdapter(child: _buildViewAllButton(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    final doctorName = _doctor?.name ?? 'Doctor';
    final hospitalName = _doctor?.hospitalName ?? 'MedSwift';
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          tooltip: 'Logout',
          icon: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
            child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
          ),
          onPressed: () async {
            await AuthService.logoutDoctor();
            if (mounted) {
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (r) => false);
            }
          },
        ),
        const SizedBox(width: 8),
      ],
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back,',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
            Text(doctorName,
                style: GoogleFonts.dmSans(
                    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.dark)),
            Text(hospitalName,
                style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(child: _StatCard(value: '$_todayCount', label: 'Transfers Today', color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(value: '$_criticalPending', label: 'Critical Pending', color: AppColors.critical)),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK ACTIONS',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          // Generate QR
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateTransferScreen())).then((_) => _load()),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generate Transfer QR',
                            style: GoogleFonts.dmSans(
                                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        Text('Create new patient transfer',
                            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.blue[100])),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Scan QR
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanQrScreen())).then((_) => _load()),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.dark, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan QR to Review',
                            style: GoogleFonts.dmSans(
                                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                        Text('Receive incoming transfer',
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildRecentHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text('RECENT TRANSFERS',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.muted, letterSpacing: 1.5)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransferHistoryScreen())),
            child: Text('View All',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferTile(PatientTransfer t, BuildContext context) {
    final riskColor = AppTheme.riskColor(t.riskLevel);
    final riskBg = AppTheme.riskBgColor(t.riskLevel);
    final diff = DateTime.now().difference(t.createdAt);
    String timeAgo;
    if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
    else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
    else timeAgo = '${diff.inDays}d ago';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ReviewScreen(transfer: t))).then((_) => _load()),
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                  decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.patientName,
                          style: GoogleFonts.dmSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      Text('${t.diagnosis.length > 25 ? t.diagnosis.substring(0, 25) + '…' : t.diagnosis} • $timeAgo',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: riskBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(t.riskLevel.toUpperCase(),
                      style: GoogleFonts.dmSans(
                          fontSize: 10, fontWeight: FontWeight.w700, color: riskColor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TransferHistoryScreen())),
        child: Text('View all ${_transfers.length} transfers →',
            style: GoogleFonts.dmSans(color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
