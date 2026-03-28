// This screen is replaced by PatientAuthScreen (phone + PIN auth).
// Kept for compatibility — immediately redirects.
import 'package:flutter/material.dart';
import '../auth/patient_auth_screen.dart';

class PatientLoginScreen extends StatelessWidget {
  const PatientLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientAuthScreen();
  }
}
