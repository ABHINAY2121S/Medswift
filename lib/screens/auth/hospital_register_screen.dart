import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'doctor_login_screen.dart';

/// Hospital registration screen — no OTP needed.
/// Admins fill in hospital details → saved to Firestore → proceed to add a doctor.
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
  bool _loading = false;

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    _licenseCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: error ? AppColors.danger : AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final hospital = await AuthService.registerHospital(
        name: _hospitalNameCtrl.text.trim(),
        licenseNo: _licenseCtrl.text.trim().toUpperCase(),
        city: _cityCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      setState(() => _loading = false);
      _snack('Hospital registered! Now add your doctor account.');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => DoctorLoginScreen(prefilledHospital: hospital)));
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack('Registration failed: $e', error: true);
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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.dark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                    color: AppColors.blueLight, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.local_hospital_rounded, size: 28, color: AppColors.primary),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 16),
              Text('Register Hospital',
                  style: GoogleFonts.dmSans(
                      fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark))
                  .animate().fadeIn(delay: 80.ms),
              Text('Register your hospital once — doctors join using the hospital name',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted))
                  .animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 28),

              _HospField(
                controller: _hospitalNameCtrl,
                label: 'Hospital Name *',
                hint: 'e.g. City General Hospital',
                icon: Icons.business_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _HospField(
                controller: _licenseCtrl,
                label: 'Medical License No. *',
                hint: 'e.g. MCI-2024-0847',
                icon: Icons.verified_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _HospField(
                controller: _cityCtrl,
                label: 'City',
                hint: 'e.g. Mumbai',
                icon: Icons.location_city_rounded,
                validator: null,
              ),
              const SizedBox(height: 12),
              _HospField(
                controller: _phoneCtrl,
                label: 'Admin Phone No. *',
                hint: '9876543210',
                icon: Icons.phone_rounded,
                keyboard: TextInputType.phone,
                validator: (v) =>
                    (v?.trim().length ?? 0) < 10 ? 'Valid phone required' : null,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _register,
                  icon: _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 18),
                  label: Text(
                    _loading ? 'Registering…' : 'Register Hospital',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'No OTP required. After registration you\'ll be taken to add a doctor account.',
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.primary)),
                  ),
                ]),
              ),
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

  const _HospField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger)),
        ),
      ),
    ]);
  }
}
