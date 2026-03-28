import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/pin_input_widget.dart';
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
  String _loginPin = '';
  bool _loginPinComplete = false;

  // Register
  final _nameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _regPin = '';
  String _regConfirmPin = '';
  bool _regPinComplete = false;
  bool _regConfirmComplete = false;

  bool _loading = false;
  bool _showLoginPin = false;
  bool _showRegPin = false;
  bool _showRegConfirm = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginPhoneCtrl.dispose();
    _nameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: err ? AppColors.danger : AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final phone = _loginPhoneCtrl.text.trim();
    if (phone.length < 10) { _snack('Enter a valid phone number', err: true); return; }
    if (!_loginPinComplete) { _snack('Enter your 4-digit PIN', err: true); return; }

    setState(() => _loading = true);
    final result = await AuthService.loginPatientWithPin(phone: phone, pin: _loginPin);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.error != null) {
      _snack(result.error!, err: true);
      return;
    }
    _goToDashboard();
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<void> _pickDob() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (dt != null) {
      _dobCtrl.text =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      setState(() {});
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Full name required', err: true); return; }
    if (_regPhoneCtrl.text.trim().length < 10) { _snack('Valid phone required', err: true); return; }
    if (_dobCtrl.text.trim().isEmpty) { _snack('Date of birth required', err: true); return; }
    if (!_regPinComplete) { _snack('Set your 4-digit security PIN', err: true); return; }
    if (!_regConfirmComplete) { _snack('Confirm your PIN', err: true); return; }
    if (_regPin != _regConfirmPin) { _snack('PINs do not match', err: true); return; }

    setState(() => _loading = true);
    final result = await AuthService.registerPatient(
      name: _nameCtrl.text.trim(),
      phone: _regPhoneCtrl.text.trim(),
      pin: _regPin,
      dob: _dobCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.error != null) {
      _snack(result.error!, err: true);
      return;
    }

    final patient = result.patient!;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 56),
          const SizedBox(height: 12),
          Text('Registration Successful!',
              style: GoogleFonts.dmSans(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Your Patient ID', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.greenLight, borderRadius: BorderRadius.circular(14)),
            child: Text(patient.patientId,
                style: GoogleFonts.spaceMono(
                    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ),
          const SizedBox(height: 8),
          Text('Show this ID to doctors who treat you.',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Login anytime with your phone + PIN.',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
              textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); _goToDashboard(); },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Continue',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const PatientDashboardScreen()),
        (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)
                ]),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.dark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: AppColors.greenLight, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.person_rounded, size: 28, color: AppColors.accent),
            ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 16),
            Text('Patient Access',
                style: GoogleFonts.dmSans(
                    fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark))
                .animate().fadeIn(delay: 80.ms),
            Text('Phone number + 4-digit security PIN',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted))
                .animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
                  ]),
              child: Column(children: [
                TabBar(
                  controller: _tab,
                  labelStyle:
                      GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppColors.border,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.muted,
                  padding: const EdgeInsets.only(top: 4),
                  tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
                ),
                SizedBox(
                  height: 380,
                  child: TabBarView(
                      controller: _tab,
                      children: [_buildLogin(), _buildRegister()]),
                ),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhoneField(controller: _loginPhoneCtrl, color: AppColors.accent),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Security PIN',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              GestureDetector(
                onTap: () => setState(() => _showLoginPin = !_showLoginPin),
                child: Text(_showLoginPin ? 'Hide' : 'Show',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.accent,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PinInputWidget(
            key: ValueKey('login-pin-$_showLoginPin'),
            accentColor: AppColors.accent,
            obscure: !_showLoginPin,
            onCompleted: (pin) => setState(() {
              _loginPin = pin;
              _loginPinComplete = true;
            }),
          ),
          const SizedBox(height: 24),
          _Btn('Login', AppColors.accent, _loading ? null : _login, _loading),
        ],
      ),
    );
  }

  Widget _buildRegister() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextField(_nameCtrl, 'Full Name', Icons.person_rounded, AppColors.accent),
          const SizedBox(height: 10),
          _PhoneField(controller: _regPhoneCtrl, color: AppColors.accent),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDob,
            child: AbsorbPointer(
              child: TextField(
                controller: _dobCtrl,
                decoration: InputDecoration(
                    hintText: 'Date of Birth',
                    hintStyle:
                        GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
                    prefixIcon: const Icon(Icons.calendar_today_rounded,
                        color: AppColors.accent, size: 18),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Create Security PIN',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              GestureDetector(
                onTap: () => setState(() => _showRegPin = !_showRegPin),
                child: Text(_showRegPin ? 'Hide' : 'Show',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.accent,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PinInputWidget(
            key: ValueKey('reg-pin-$_showRegPin'),
            accentColor: AppColors.accent,
            obscure: !_showRegPin,
            onCompleted: (pin) => setState(() {
              _regPin = pin;
              _regPinComplete = true;
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Confirm PIN',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              GestureDetector(
                onTap: () => setState(() => _showRegConfirm = !_showRegConfirm),
                child: Text(_showRegConfirm ? 'Hide' : 'Show',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.accent,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PinInputWidget(
            key: ValueKey('reg-confirm-$_showRegConfirm'),
            accentColor: AppColors.accent,
            obscure: !_showRegConfirm,
            onCompleted: (pin) => setState(() {
              _regConfirmPin = pin;
              _regConfirmComplete = true;
            }),
          ),
          const SizedBox(height: 24),
          _Btn('Create Account', AppColors.accent, _loading ? null : _register, _loading),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final Color color;
  const _PhoneField({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
          hintText: 'Mobile number (e.g. 9876543210)',
          hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
          prefixText: '+91 ',
          prefixStyle:
              GoogleFonts.dmSans(color: AppColors.accent, fontWeight: FontWeight.w600),
          prefixIcon: Icon(Icons.phone_rounded, color: color, size: 18),
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color color;
  const _TextField(this.controller, this.hint, this.icon, this.color);

  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
          prefixIcon: Icon(icon, color: color, size: 18),
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)));
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  const _Btn(this.label, this.color, this.onTap, this.loading);

  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14))));
}
