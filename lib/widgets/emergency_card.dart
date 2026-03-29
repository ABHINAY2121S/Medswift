import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transfer.dart';

class EmergencyCard extends StatefulWidget {
  final String patientName;
  final String patientId;
  final String allergies;
  final String medications;
  final String bloodGroup;
  final String emergencyContact;
  final PatientTransfer? latestTransfer;

  const EmergencyCard({
    super.key,
    required this.patientName,
    required this.patientId,
    required this.allergies,
    required this.medications,
    required this.bloodGroup,
    required this.emergencyContact,
    this.latestTransfer,
  });

  static Future<void> show(
    BuildContext context, {
    required String patientName,
    required String patientId,
    required String allergies,
    required String medications,
    required String bloodGroup,
    required String emergencyContact,
    PatientTransfer? latestTransfer,
  }) {
    // Full brightness when SOS is open
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.red,
      statusBarIconBrightness: Brightness.light,
    ));
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => EmergencyCard(
        patientName: patientName,
        patientId: patientId,
        allergies: allergies,
        medications: medications,
        bloodGroup: bloodGroup,
        emergencyContact: emergencyContact,
        latestTransfer: latestTransfer,
      ),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(anim), child: child),
      ),
    ).then((_) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ));
    });
  }

  @override
  State<EmergencyCard> createState() => _EmergencyCardState();
}

class _EmergencyCardState extends State<EmergencyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDC2626),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Row(
                      children: [
                        Icon(Icons.emergency_rounded,
                            color: Colors.white
                                .withOpacity(0.6 + _pulseCtrl.value * 0.4),
                            size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '🚨 MEDICAL EMERGENCY',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white
                                  .withOpacity(0.7 + _pulseCtrl.value * 0.3),
                              letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('CLOSE',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // ── Patient identity ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(children: [
                        Text(widget.patientName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1)),
                        const SizedBox(height: 4),
                        Text(widget.patientId,
                            style: GoogleFonts.spaceMono(
                                fontSize: 13, color: Colors.white70)),
                        if (widget.latestTransfer != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.latestTransfer!.patientAge}y  •  ${widget.latestTransfer!.patientGender}',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 12),

                    // ── Blood group ────────────────────────────────────────
                    if (widget.bloodGroup.isNotEmpty)
                      _BigTile(
                        icon: '🩸',
                        label: 'BLOOD GROUP',
                        value: widget.bloodGroup,
                        valueSize: 48,
                      ),

                    const SizedBox(height: 12),

                    // ── Allergies ─────────────────────────────────────────
                    _BigTile(
                      icon: '⚠',
                      label: 'ALLERGIES — CRITICAL',
                      value: widget.allergies.isEmpty ? 'None known' : widget.allergies,
                      valueSize: 22,
                      highlight: widget.allergies.isNotEmpty && widget.allergies.toLowerCase() != 'none',
                    ),

                    const SizedBox(height: 12),

                    // ── Current medications ──────────────────────────────
                    _BigTile(
                      icon: '💊',
                      label: 'CURRENT MEDICATIONS',
                      value: widget.medications.isEmpty ? 'None' : widget.medications,
                      valueSize: 16,
                    ),

                    const SizedBox(height: 12),

                    // ── Latest vitals ────────────────────────────────────
                    if (widget.latestTransfer != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LAST KNOWN VITALS',
                                style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white70,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            Row(children: [
                              _VitalBadge('BP', widget.latestTransfer!.vitals.bp),
                              const SizedBox(width: 8),
                              _VitalBadge('PULSE', widget.latestTransfer!.vitals.pulse),
                              const SizedBox(width: 8),
                              _VitalBadge('SpO2', widget.latestTransfer!.vitals.spo2),
                              const SizedBox(width: 8),
                              _VitalBadge('TEMP', '${widget.latestTransfer!.vitals.temp}°'),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Emergency contact ─────────────────────────────────
                    if (widget.emergencyContact.isNotEmpty)
                      _BigTile(
                        icon: '📞',
                        label: 'EMERGENCY CONTACT',
                        value: widget.emergencyContact,
                        valueSize: 22,
                      ),

                    const SizedBox(height: 24),

                    // ── Bottom note ───────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'MEDSWIFT — Smart Patient Transfer System\nThis card contains critical medical information.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: Colors.white60),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Big info tile ───────────────────────────────────────────────────────────
class _BigTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final double valueSize;
  final bool highlight;

  const _BigTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueSize,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.white.withOpacity(0.25)
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: Colors.white.withOpacity(0.6), width: 1.5)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: valueSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2)),
      ]),
    );
  }
}

// ── Vital badge ─────────────────────────────────────────────────────────────
class _VitalBadge extends StatelessWidget {
  final String label;
  final String value;
  const _VitalBadge(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value.isEmpty ? '—' : value,
              style: GoogleFonts.spaceMono(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white60)),
        ]),
      ),
    );
  }
}
