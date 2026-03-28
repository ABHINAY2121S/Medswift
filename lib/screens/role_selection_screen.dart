import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'doctor/doctor_dashboard_screen.dart';
import 'patient/patient_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo & Title
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.favorite_rounded,
                    size: 38, color: AppColors.primary),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
              const SizedBox(height: 16),
              Text(
                'MedSwift',
                style: GoogleFonts.spaceMono(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                  letterSpacing: -1,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 6),
              Text(
                'Smart Patient Transfer System',
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: AppColors.muted),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 48),
              Text(
                'SELECT YOUR ROLE',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 1.5,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),

              // Doctor Card
              _RoleCard(
                icon: Icons.local_hospital_rounded,
                iconBg: AppColors.blueLight,
                iconColor: AppColors.primary,
                title: 'Doctor / Nurse',
                subtitle: 'Transfer & review patients',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DoctorDashboardScreen()),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 12),

              // Patient Card
              _RoleCard(
                icon: Icons.person_rounded,
                iconBg: AppColors.greenLight,
                iconColor: AppColors.accent,
                title: 'Patient',
                subtitle: 'View your medical journey',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PatientLoginScreen()),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

              const SizedBox(height: 24),
              Text(
                'Receiving doctor? Open the link or scan QR code.',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.muted),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms),
              const Spacer(),
              // Version
              Text('v1.0.0 • Emergency transfer tool',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.muted.withOpacity(0.6))),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFD1D5DB), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
