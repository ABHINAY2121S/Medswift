import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/transfer_service.dart';
import 'patient_dashboard_screen.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithId() async {
    if (_idCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await TransferService.setPatientId(_idCtrl.text.trim().toUpperCase());
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const PatientDashboardScreen()));
    }
  }

  Future<void> _sendOtp() async {
    if (_phoneCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid phone number', style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() { _loading = true; });
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _loading = false; _otpSent = true; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('OTP sent to ${_phoneCtrl.text.trim()} (demo: 1234)',
          style: GoogleFonts.dmSans()),
      backgroundColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim() != '1234') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invalid OTP. Try 1234 for demo.', style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _loading = true);
    await TransferService.setPatientId('PATIENT-${_phoneCtrl.text.trim()}');
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const PatientDashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.person_rounded, size: 28, color: AppColors.accent),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 16),
              Text('Patient Access',
                  style: GoogleFonts.dmSans(
                      fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark))
                  .animate().fadeIn(delay: 100.ms),
              Text('View your medical journey securely',
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted))
                  .animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 28),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tab,
                      labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
                      indicatorColor: AppColors.accent,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: AppColors.border,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.muted,
                      padding: const EdgeInsets.only(top: 4),
                      tabs: const [
                        Tab(text: 'Patient ID'),
                        Tab(text: 'Mobile OTP'),
                      ],
                    ),
                    SizedBox(
                      height: 200,
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          // Patient ID tab
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _idCtrl,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. MR-2024-0847',
                                    hintStyle: GoogleFonts.dmSans(color: AppColors.muted),
                                    filled: true,
                                    fillColor: AppColors.bg,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none),
                                    prefixIcon: const Icon(Icons.fingerprint_rounded,
                                        color: AppColors.accent),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _loginWithId,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _loading
                                        ? const SizedBox(width: 20, height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text('Access Records',
                                            style: GoogleFonts.dmSans(
                                                fontWeight: FontWeight.w700, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // OTP tab
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                if (!_otpSent)
                                  Row(children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          hintText: '+91 9876543210',
                                          hintStyle: GoogleFonts.dmSans(color: AppColors.muted),
                                          filled: true,
                                          fillColor: AppColors.bg,
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none),
                                          prefixIcon: const Icon(Icons.phone_rounded,
                                              color: AppColors.accent),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _loading ? null : _sendOtp,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12))),
                                      child: _loading
                                          ? const SizedBox(width: 16, height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : Text('Send',
                                              style: GoogleFonts.dmSans(
                                                  fontWeight: FontWeight.w700, color: Colors.white)),
                                    ),
                                  ])
                                else
                                  Column(children: [
                                    TextField(
                                      controller: _otpCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.spaceMono(
                                          fontSize: 22, fontWeight: FontWeight.w700,
                                          letterSpacing: 8),
                                      maxLength: 4,
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: '----',
                                        filled: true,
                                        fillColor: AppColors.bg,
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _verifyOtp,
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.accent,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12))),
                                        child: _loading
                                            ? const SizedBox(width: 20, height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : Text('Verify OTP',
                                                style: GoogleFonts.dmSans(
                                                    fontWeight: FontWeight.w700, color: Colors.white)),
                                      ),
                                    ),
                                  ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

              const Spacer(),
              Text('Demo tip: Use ID "MR-2024-0847" or phone with OTP "1234"',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
