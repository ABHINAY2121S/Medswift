import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/pin_input_widget.dart';
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
  String _loginPin = '';
  bool _loginPinComplete = false;
  bool _showLoginPin = false;

  // Register tab
  final _nameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  String _regPin = '';
  String _regConfirmPin = '';
  bool _regPinComplete = false;
  bool _regConfirmComplete = false;
  bool _showRegPin = false;
  bool _showRegConfirm = false;

  HospitalProfile? _selectedHospital;
  List<HospitalProfile> _hospitals = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // Don't set _selectedHospital here — _loadHospitals will resolve it from
    // the Firestore list by ID so the object instance matches.
    if (widget.prefilledHospital != null) _tab.index = 1;
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    final hospitals = await AuthService.getHospitals();
    if (mounted) {
      setState(() {
        _hospitals = hospitals;
        // Re-resolve the selected hospital from the loaded list by ID
        // This ensures the dropdown value is the SAME object instance as in the items list
        if (widget.prefilledHospital != null) {
          _selectedHospital = hospitals.where(
            (h) => h.id == widget.prefilledHospital!.id
          ).firstOrNull;
          // If not found in list yet (race), keep the prefilled one as null
          // and let user pick — avoids the duplicate-value crash
        }
      });
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: err ? AppColors.danger : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) { _snack('Enter a valid phone number', err: true); return; }
    if (!_loginPinComplete) { _snack('Enter your 4-digit PIN', err: true); return; }

    setState(() => _loading = true);
    final result = await AuthService.loginDoctorWithPin(phone: phone, pin: _loginPin);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.error != null) {
      _snack(result.error!, err: true);
      return;
    }
    _goToDashboard();
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Name required', err: true); return; }
    if (_regPhoneCtrl.text.trim().length < 10) { _snack('Valid phone required', err: true); return; }
    if (_licenseCtrl.text.trim().isEmpty) { _snack('License number required', err: true); return; }
    if (!_regPinComplete) { _snack('Set a 4-digit security PIN', err: true); return; }
    if (!_regConfirmComplete) { _snack('Confirm your PIN', err: true); return; }
    if (_regPin != _regConfirmPin) { _snack('PINs do not match', err: true); return; }

    setState(() => _loading = true);
    final error = await AuthService.registerDoctor(
      name: _nameCtrl.text.trim(),
      phone: _regPhoneCtrl.text.trim(),
      pin: _regPin,
      hospitalId: _selectedHospital?.id ?? 'SELF',
      hospitalName: _selectedHospital?.name ?? 'Independent Practice',
      licenseNo: _licenseCtrl.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _snack(error, err: true);
      return;
    }
    _goToDashboard();
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
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
                  color: AppColors.blueLight, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.medical_services_rounded, size: 28, color: AppColors.primary),
            ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 16),
            Text('Doctor / Nurse Access',
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
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppColors.border,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.muted,
                  padding: const EdgeInsets.only(top: 4),
                  tabs: const [Tab(text: 'Login'), Tab(text: 'New Doctor')],
                ),
                SizedBox(
                  // Large enough for New Doctor tab (5 fields + 2 PINs + button)
                  height: 600,
                  child: TabBarView(
                      controller: _tab,
                      children: [_buildLoginTab(), _buildRegisterTab()]),
                ),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HospitalRegisterScreen())),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: Text('Register a New Hospital',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
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
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Phone Number'),
          const SizedBox(height: 8),
          _PhoneField(controller: _phoneCtrl),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _FieldLabel('Security PIN'),
            GestureDetector(
              onTap: () => setState(() => _showLoginPin = !_showLoginPin),
              child: Text(_showLoginPin ? 'Hide' : 'Show',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          PinInputWidget(
            key: ValueKey('doc-login-$_showLoginPin'),
            accentColor: AppColors.primary,
            obscure: !_showLoginPin,
            onCompleted: (pin) => setState(() {
              _loginPin = pin;
              _loginPinComplete = true;
            }),
          ),
          const SizedBox(height: 24),
          _BigBtn('Login', AppColors.primary, _loading ? null : _login, _loading),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmallField(controller: _nameCtrl, hint: 'Full Name (Dr. ...)', icon: Icons.person_rounded),
          const SizedBox(height: 8),
          _SmallField(controller: _licenseCtrl, hint: 'Medical License No.', icon: Icons.verified_rounded),
          const SizedBox(height: 8),
          _PhoneField(controller: _regPhoneCtrl),
          const SizedBox(height: 10),

          // Hospital picker
          _FieldLabel('Hospital'),
          const SizedBox(height: 6),
          DropdownButtonFormField<HospitalProfile?>(
            value: _selectedHospital,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.business_rounded, color: AppColors.primary, size: 18),
            ),
            hint: Text('Select Hospital', style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13)),
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
            items: [
              DropdownMenuItem<HospitalProfile?>(
                value: null,
                child: Text('Independent Practice', style: GoogleFonts.dmSans()),
              ),
              ..._hospitals.map((h) => DropdownMenuItem(
                    value: h,
                    child: Text(h.name, style: GoogleFonts.dmSans()),
                  )),
            ],
            onChanged: (h) => setState(() => _selectedHospital = h),
          ),
          const SizedBox(height: 16),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _FieldLabel('Create Security PIN'),
            GestureDetector(
              onTap: () => setState(() => _showRegPin = !_showRegPin),
              child: Text(_showRegPin ? 'Hide' : 'Show',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          PinInputWidget(
            key: ValueKey('doc-reg-pin-$_showRegPin'),
            accentColor: AppColors.primary,
            obscure: !_showRegPin,
            onCompleted: (pin) => setState(() {
              _regPin = pin;
              _regPinComplete = true;
            }),
          ),
          const SizedBox(height: 16),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _FieldLabel('Confirm PIN'),
            GestureDetector(
              onTap: () => setState(() => _showRegConfirm = !_showRegConfirm),
              child: Text(_showRegConfirm ? 'Hide' : 'Show',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          PinInputWidget(
            key: ValueKey('doc-reg-confirm-$_showRegConfirm'),
            accentColor: AppColors.primary,
            obscure: !_showRegConfirm,
            onCompleted: (pin) => setState(() {
              _regConfirmPin = pin;
              _regConfirmComplete = true;
            }),
          ),
          const SizedBox(height: 24),
          _BigBtn('Create Doctor Account', AppColors.primary, _loading ? null : _register, _loading),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark));
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  const _PhoneField({required this.controller});
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
          hintText: 'Mobile number (e.g. 9876543210)',
          hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
          prefixText: '+91 ',
          prefixStyle: GoogleFonts.dmSans(color: AppColors.primary, fontWeight: FontWeight.w600),
          prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 18),
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
}

class _SmallField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _SmallField({required this.controller, required this.hint, required this.icon});
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)));
}

class _BigBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  const _BigBtn(this.label, this.color, this.onTap, this.loading);
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
