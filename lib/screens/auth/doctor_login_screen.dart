import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../doctor/doctor_dashboard_screen.dart';
import 'hospital_register_screen.dart';

class DoctorLoginScreen extends StatefulWidget {
  final HospitalProfile? prefilledHospital;
  const DoctorLoginScreen({super.key, this.prefilledHospital});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Login tab
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _loginVerificationId;
  PhoneAuthCredential? _autoCredential;

  // Register tab
  final _nameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regOtpCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  String? _regVerificationId;
  PhoneAuthCredential? _regAutoCredential;

  bool _loading = false;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    if (widget.prefilledHospital != null) _tab.index = 1;
  }

  @override
  void dispose() {
    _tab.dispose();
    _phoneCtrl.dispose(); _otpCtrl.dispose();
    _nameCtrl.dispose(); _regPhoneCtrl.dispose();
    _regOtpCtrl.dispose(); _licenseCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: err ? AppColors.danger : AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  // ── Login OTP ────────────────────────────────────────────────────────────
  Future<void> _sendLoginOtp() async {
    if (_phoneCtrl.text.trim().length < 10) { _snack('Enter valid phone', err: true); return; }
    setState(() => _loading = true);
    await AuthService.sendOtp(
      _phoneCtrl.text.trim(),
      onCodeSent: (vid) {
        if (mounted) setState(() { _loading = false; _loginVerificationId = vid; });
        _snack('OTP sent ✓');
        _startResendTimer();
      },
      onError: (e) {
        if (mounted) { setState(() => _loading = false); _snack(e, err: true); }
      },
      onAutoVerified: (credential) {
        if (mounted) setState(() { _autoCredential = credential; _loading = false; });
        _completeLogin(credential: credential);
      },
    );
  }

  Future<void> _verifyLoginOtp() async {
    if (_loginVerificationId == null && _autoCredential == null) {
      _snack('Please request OTP first', err: true); return;
    }
    setState(() => _loading = true);
    try {
      final User user;
      if (_autoCredential != null) {
        user = await AuthService.signInWithCredential(_autoCredential!);
      } else {
        user = await AuthService.verifyOtp(_loginVerificationId!, _otpCtrl.text.trim());
      }
      await _completeLogin(user: user);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.code == 'invalid-verification-code' ? 'Wrong OTP. Try again.' : (e.message ?? 'Verification failed'), err: true);
      }
    }
  }

  Future<void> _completeLogin({User? user, PhoneAuthCredential? credential}) async {
    final u = user ?? await AuthService.signInWithCredential(credential!);
    final doctor = await AuthService.getDoctorByUid(u.uid);
    setState(() => _loading = false);
    if (doctor == null) {
      _snack('Phone not registered as doctor. Please register.', err: true);
      if (mounted) setState(() => _tab.index = 1);
      await AuthService.logoutDoctor();
      return;
    }
    await AuthService.loginDoctor(doctor);
    if (mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
          (r) => false);
    }
  }

  // ── Register OTP ─────────────────────────────────────────────────────────
  Future<void> _sendRegOtp() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Name required', err: true); return; }
    if (_regPhoneCtrl.text.trim().length < 10) { _snack('Valid phone required', err: true); return; }
    if (_licenseCtrl.text.trim().isEmpty) { _snack('License no. required', err: true); return; }
    setState(() => _loading = true);
    await AuthService.sendOtp(
      _regPhoneCtrl.text.trim(),
      onCodeSent: (vid) {
        if (mounted) setState(() { _loading = false; _regVerificationId = vid; });
        _snack('OTP sent ✓');
        _startResendTimer();
      },
      onError: (e) {
        if (mounted) { setState(() => _loading = false); _snack(e, err: true); }
      },
      onAutoVerified: (credential) {
        if (mounted) setState(() { _regAutoCredential = credential; _loading = false; });
      },
    );
  }

  Future<void> _verifyRegOtp() async {
    if (_regVerificationId == null && _regAutoCredential == null) {
      _snack('Please request OTP first', err: true); return;
    }
    setState(() => _loading = true);
    try {
      final User user;
      if (_regAutoCredential != null) {
        user = await AuthService.signInWithCredential(_regAutoCredential!);
      } else {
        user = await AuthService.verifyOtp(_regVerificationId!, _regOtpCtrl.text.trim());
      }
      final hospital = widget.prefilledHospital;
      final doctor = await AuthService.registerDoctor(
        uid: user.uid,
        name: _nameCtrl.text.trim(),
        phone: _regPhoneCtrl.text.trim(),
        hospitalId: hospital?.id ?? 'SELF',
        hospitalName: hospital?.name ?? 'Independent Practice',
        licenseNo: _licenseCtrl.text.trim().toUpperCase(),
      );
      await AuthService.loginDoctor(doctor);
      setState(() => _loading = false);
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
            (r) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.code == 'invalid-verification-code' ? 'Wrong OTP.' : (e.message ?? 'Failed'), err: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.dark)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(width: 56, height: 56,
                decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.medical_services_rounded, size: 28, color: AppColors.primary))
                .animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 16),
            Text('Doctor / Nurse Access',
                style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark))
                .animate().fadeIn(delay: 80.ms),
            Text('Verified medical staff only • Real SMS OTP',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted))
                .animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
              child: Column(children: [
                TabBar(
                  controller: _tab,
                  labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppColors.border,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.muted,
                  padding: const EdgeInsets.only(top: 4),
                  tabs: const [Tab(text: 'Login'), Tab(text: 'New Doctor')],
                ),
                SizedBox(
                  height: _loginVerificationId != null || _regVerificationId != null ? 220 : 300,
                  child: TabBarView(
                    controller: _tab,
                    children: [_buildLoginTab(), _buildRegisterTab()],
                  ),
                ),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HospitalRegisterScreen())),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: Text('Register a New Hospital', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _loginVerificationId == null
          ? Column(children: [
              _PhoneField(controller: _phoneCtrl, hint: 'Mobile number (e.g. 9876543210)'),
              const SizedBox(height: 12),
              _BigBtn('Send OTP via SMS', AppColors.primary, _loading ? null : _sendLoginOtp, _loading),
            ])
          : Column(children: [
              _OtpField(controller: _otpCtrl),
              const SizedBox(height: 6),
              Text('OTP sent to +91-${_phoneCtrl.text}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              _BigBtn('Verify & Login', AppColors.accent, _loading ? null : _verifyLoginOtp, _loading),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _resendSeconds > 0 ? null : () { setState(() => _loginVerificationId = null); },
                child: Text(_resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : '← Resend OTP',
                    style: GoogleFonts.dmSans(color: _resendSeconds > 0 ? AppColors.muted : AppColors.primary)),
              ),
            ]),
    );
  }

  Widget _buildRegisterTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _regVerificationId == null
          ? SingleChildScrollView(child: Column(children: [
              _SmallField(controller: _nameCtrl, hint: 'Full Name (Dr. ...)', icon: Icons.person_rounded),
              const SizedBox(height: 8),
              _SmallField(controller: _licenseCtrl, hint: 'Medical License No.', icon: Icons.verified_rounded),
              const SizedBox(height: 8),
              _PhoneField(controller: _regPhoneCtrl, hint: 'Mobile number'),
              if (widget.prefilledHospital != null) ...[
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.business_rounded, color: AppColors.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(widget.prefilledHospital!.name,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              _BigBtn('Send OTP via SMS', AppColors.primary, _loading ? null : _sendRegOtp, _loading),
            ]))
          : Column(children: [
              _OtpField(controller: _regOtpCtrl),
              const SizedBox(height: 10),
              _BigBtn('Create Doctor Account', AppColors.accent, _loading ? null : _verifyRegOtp, _loading),
              TextButton(
                onPressed: _resendSeconds > 0 ? null : () { setState(() => _regVerificationId = null); },
                child: Text(_resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : '← Resend OTP',
                    style: GoogleFonts.dmSans(color: _resendSeconds > 0 ? AppColors.muted : AppColors.primary)),
              ),
            ]),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _PhoneField({required this.controller, required this.hint});
  @override
  Widget build(BuildContext context) => TextField(controller: controller,
    keyboardType: TextInputType.phone,
    decoration: InputDecoration(hintText: hint,
      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
      prefixText: '+91 ',
      prefixStyle: GoogleFonts.dmSans(color: AppColors.primary, fontWeight: FontWeight.w600),
      prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 18),
      filled: true, fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ));
}

class _SmallField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _SmallField({required this.controller, required this.hint, required this.icon});
  @override
  Widget build(BuildContext context) => TextField(controller: controller,
    decoration: InputDecoration(hintText: hint,
      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
      filled: true, fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    ));
}

class _OtpField extends StatelessWidget {
  final TextEditingController controller;
  const _OtpField({required this.controller});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, keyboardType: TextInputType.number,
    textAlign: TextAlign.center, maxLength: 6,
    style: GoogleFonts.spaceMono(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
    decoration: InputDecoration(counterText: '',
      hintText: '– – – – – –', hintStyle: GoogleFonts.spaceMono(fontSize: 18, color: AppColors.muted, letterSpacing: 6),
      filled: true, fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    ));
}

class _BigBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  const _BigBtn(this.label, this.color, this.onTap, this.loading);
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity,
    child: ElevatedButton(onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: loading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14))));
}
