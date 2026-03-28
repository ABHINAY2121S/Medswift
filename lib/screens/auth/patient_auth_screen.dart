import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../patient/patient_dashboard_screen.dart';

class PatientAuthScreen extends StatefulWidget {
  const PatientAuthScreen({super.key});

  @override
  State<PatientAuthScreen> createState() => _PatientAuthScreenState();
}

class _PatientAuthScreenState extends State<PatientAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Login
  final _loginPhoneCtrl = TextEditingController();
  final _loginOtpCtrl = TextEditingController();
  String? _loginVerificationId;

  // Register
  final _nameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _regOtpCtrl = TextEditingController();
  String? _regVerificationId;
  PhoneAuthCredential? _regAutoCredential;

  bool _loading = false;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginPhoneCtrl.dispose(); _loginOtpCtrl.dispose();
    _nameCtrl.dispose(); _regPhoneCtrl.dispose();
    _dobCtrl.dispose(); _regOtpCtrl.dispose();
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

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> _sendLoginOtp() async {
    if (_loginPhoneCtrl.text.trim().length < 10) { _snack('Enter valid phone', err: true); return; }
    setState(() => _loading = true);
    await AuthService.sendOtp(
      _loginPhoneCtrl.text.trim(),
      onCodeSent: (vid) {
        if (mounted) setState(() { _loading = false; _loginVerificationId = vid; });
        _snack('OTP sent ✓');
        _startResendTimer();
      },
      onError: (e) {
        if (mounted) { setState(() => _loading = false); _snack(e, err: true); }
      },
      onAutoVerified: (credential) => _completeLogin(credential: credential),
    );
  }

  Future<void> _verifyLoginOtp() async {
    if (_loginVerificationId == null) { _snack('Please request OTP first', err: true); return; }
    setState(() => _loading = true);
    try {
      final user = await AuthService.verifyOtp(_loginVerificationId!, _loginOtpCtrl.text.trim());
      await _completeLogin(user: user);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.code == 'invalid-verification-code' ? 'Wrong OTP.' : (e.message ?? 'Failed'), err: true);
      }
    }
  }

  Future<void> _completeLogin({User? user, PhoneAuthCredential? credential}) async {
    final u = user ?? await AuthService.signInWithCredential(credential!);
    final patient = await AuthService.getPatientByUid(u.uid);
    setState(() => _loading = false);
    if (patient == null) {
      _snack('Phone not registered. Please register first.', err: true);
      if (mounted) _tab.animateTo(1);
      await AuthService.logoutPatient();
      return;
    }
    await AuthService.loginPatient(patient);
    if (mounted) _goToDashboard();
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<void> _pickDob() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (dt != null) {
      _dobCtrl.text = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      setState(() {});
    }
  }

  Future<void> _sendRegOtp() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Full name required', err: true); return; }
    if (_regPhoneCtrl.text.trim().length < 10) { _snack('Valid phone required', err: true); return; }
    if (_dobCtrl.text.trim().isEmpty) { _snack('Date of birth required', err: true); return; }
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
      final patient = await AuthService.registerPatient(
        uid: user.uid,
        name: _nameCtrl.text.trim(),
        phone: _regPhoneCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
      );
      await AuthService.loginPatient(patient);
      setState(() => _loading = false);
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 48),
              const SizedBox(height: 12),
              Text('Registration Successful!',
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Your Patient ID', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(14)),
                child: Text(patient.patientId,
                    style: GoogleFonts.spaceMono(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ),
              const SizedBox(height: 8),
              Text('Show this to doctors who treat you.',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted), textAlign: TextAlign.center),
            ]),
            actions: [SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); _goToDashboard(); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Continue', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
              ))],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.code == 'invalid-verification-code' ? 'Wrong OTP.' : (e.message ?? 'Failed'), err: true);
      }
    }
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const PatientDashboardScreen()), (r) => false);
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
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.person_rounded, size: 28, color: AppColors.accent))
                .animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 16),
            Text('Patient Access',
                style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark))
                .animate().fadeIn(delay: 80.ms),
            Text('Real SMS OTP — no passwords needed',
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
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppColors.border,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.muted,
                  padding: const EdgeInsets.only(top: 4),
                  tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
                ),
                SizedBox(
                  height: (_loginVerificationId != null || _regVerificationId != null) ? 220 : 280,
                  child: TabBarView(controller: _tab, children: [_buildLogin(), _buildRegister()]),
                ),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _loginVerificationId == null
          ? Column(children: [
              _PhoneField(controller: _loginPhoneCtrl),
              const SizedBox(height: 12),
              _Btn('Send OTP via SMS', AppColors.accent, _loading ? null : _sendLoginOtp, _loading),
            ])
          : Column(children: [
              _OtpField(controller: _loginOtpCtrl),
              const SizedBox(height: 6),
              Text('OTP sent to +91-${_loginPhoneCtrl.text}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              _Btn('Verify & Login', AppColors.accent, _loading ? null : _verifyLoginOtp, _loading),
              TextButton(
                onPressed: _resendSeconds > 0 ? null : () => setState(() => _loginVerificationId = null),
                child: Text(_resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : '← Resend OTP',
                    style: GoogleFonts.dmSans(color: _resendSeconds > 0 ? AppColors.muted : AppColors.accent)),
              ),
            ]),
    );
  }

  Widget _buildRegister() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _regVerificationId == null
          ? SingleChildScrollView(child: Column(children: [
              _TextField(_nameCtrl, 'Full Name', Icons.person_rounded),
              const SizedBox(height: 8),
              _PhoneField(controller: _regPhoneCtrl),
              const SizedBox(height: 8),
              GestureDetector(onTap: _pickDob, child: AbsorbPointer(child: TextField(controller: _dobCtrl,
                decoration: InputDecoration(hintText: 'Date of Birth',
                  hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 18),
                  filled: true, fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                )))),
              const SizedBox(height: 12),
              _Btn('Send OTP via SMS', AppColors.accent, _loading ? null : _sendRegOtp, _loading),
            ]))
          : Column(children: [
              _OtpField(controller: _regOtpCtrl),
              const SizedBox(height: 10),
              _Btn('Create Account', AppColors.accent, _loading ? null : _verifyRegOtp, _loading),
              TextButton(
                onPressed: _resendSeconds > 0 ? null : () => setState(() => _regVerificationId = null),
                child: Text(_resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : '← Resend OTP',
                    style: GoogleFonts.dmSans(color: _resendSeconds > 0 ? AppColors.muted : AppColors.accent)),
              ),
            ]),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  const _PhoneField({required this.controller});
  @override
  Widget build(BuildContext context) => TextField(controller: controller,
    keyboardType: TextInputType.phone,
    decoration: InputDecoration(hintText: 'Mobile number (e.g. 9876543210)',
      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
      prefixText: '+91 ',
      prefixStyle: GoogleFonts.dmSans(color: AppColors.accent, fontWeight: FontWeight.w600),
      prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.accent, size: 18),
      filled: true, fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ));
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _TextField(this.controller, this.hint, this.icon);
  @override
  Widget build(BuildContext context) => TextField(controller: controller,
    decoration: InputDecoration(hintText: hint,
      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.accent, size: 18),
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

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  const _Btn(this.label, this.color, this.onTap, this.loading);
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
