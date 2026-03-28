import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import 'doctor_login_screen.dart';

class HospitalRegisterScreen extends StatefulWidget {
  const HospitalRegisterScreen({super.key});

  @override
  State<HospitalRegisterScreen> createState() => _HospitalRegisterScreenState();
}

class _HospitalRegisterScreenState extends State<HospitalRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalNameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  String? _verificationId;
  PhoneAuthCredential? _autoCredential;
  bool _loading = false;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _hospitalNameCtrl.dispose(); _licenseCtrl.dispose();
    _cityCtrl.dispose(); _phoneCtrl.dispose(); _otpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: error ? AppColors.danger : AppColors.accent,
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

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await AuthService.sendOtp(
      _phoneCtrl.text.trim(),
      onCodeSent: (vid) {
        if (mounted) setState(() { _loading = false; _verificationId = vid; });
        _snack('OTP sent ✓');
        _startResendTimer();
      },
      onError: (e) {
        if (mounted) { setState(() => _loading = false); _snack(e, error: true); }
      },
      onAutoVerified: (credential) {
        if (mounted) setState(() { _autoCredential = credential; _loading = false; });
      },
    );
  }

  Future<void> _verifyAndRegister() async {
    if (_verificationId == null && _autoCredential == null) {
      _snack('Please request OTP first', error: true); return;
    }
    setState(() => _loading = true);
    try {
      // Verify phone via Firebase
      if (_autoCredential == null) {
        await AuthService.verifyOtp(_verificationId!, _otpCtrl.text.trim());
      } else {
        await AuthService.signInWithCredential(_autoCredential!);
      }
      // Register hospital in Firestore
      final hospital = await AuthService.registerHospital(
        name: _hospitalNameCtrl.text.trim(),
        licenseNo: _licenseCtrl.text.trim().toUpperCase(),
        city: _cityCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      setState(() => _loading = false);
      _snack('Hospital registered! Now add your doctor account.');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => DoctorLoginScreen(prefilledHospital: hospital)));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.code == 'invalid-verification-code' ? 'Wrong OTP.' : (e.message ?? 'Verification failed'), error: true);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.local_hospital_rounded, size: 28, color: AppColors.primary))
                  .animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 16),
              Text('Register Hospital',
                  style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark))
                  .animate().fadeIn(delay: 80.ms),
              Text('Only licensed hospitals can generate patient transfer QR codes',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted))
                  .animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 28),

              if (_verificationId == null && _autoCredential == null) ...[
                _HospField(controller: _hospitalNameCtrl, label: 'Hospital Name *',
                    hint: 'e.g. City General Hospital', icon: Icons.business_rounded,
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                const SizedBox(height: 12),
                _HospField(controller: _licenseCtrl, label: 'Medical License No. *',
                    hint: 'e.g. MCI-2024-0847', icon: Icons.verified_rounded,
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                const SizedBox(height: 12),
                _HospField(controller: _cityCtrl, label: 'City',
                    hint: 'e.g. Mumbai', icon: Icons.location_city_rounded, validator: null),
                const SizedBox(height: 12),
                _HospField(controller: _phoneCtrl, label: 'Admin Phone No. *',
                    hint: '9876543210 (without +91)', icon: Icons.phone_rounded,
                    keyboard: TextInputType.phone,
                    validator: (v) => (v?.trim().length ?? 0) < 10 ? 'Valid phone required' : null),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Send OTP via SMS',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                  )),
              ] else ...[
                Container(padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.business_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_hospitalNameCtrl.text,
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.dark))),
                      ]),
                      const SizedBox(height: 2),
                      Text(_licenseCtrl.text.toUpperCase(),
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.primary)),
                    ])).animate().fadeIn(),
                const SizedBox(height: 20),
                Text('Enter OTP sent to +91-${_phoneCtrl.text}',
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: _otpCtrl, keyboardType: TextInputType.number,
                  textAlign: TextAlign.center, maxLength: 6,
                  style: GoogleFonts.spaceMono(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 10),
                  decoration: InputDecoration(counterText: '',
                    hintText: '– – – – – –', hintStyle: GoogleFonts.spaceMono(fontSize: 20, color: AppColors.muted, letterSpacing: 8),
                    filled: true, fillColor: AppColors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  )).animate().fadeIn(),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyAndRegister,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Verify & Register Hospital',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                  )),
                const SizedBox(height: 8),
                Center(child: TextButton(
                  onPressed: _resendSeconds > 0 ? null : () => setState(() { _verificationId = null; _otpCtrl.clear(); }),
                  child: Text(_resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : '← Change details',
                      style: GoogleFonts.dmSans(color: _resendSeconds > 0 ? AppColors.muted : AppColors.primary)),
                )),
              ],
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HospField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;

  const _HospField({required this.controller, required this.label, required this.hint,
    required this.icon, this.keyboard, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(height: 6),
      TextFormField(controller: controller, keyboardType: keyboard, validator: validator,
        decoration: InputDecoration(hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        )),
    ]);
  }
}
