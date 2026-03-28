import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../models/transfer.dart';
import '../../services/transfer_service.dart';
import 'review_screen.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  MobileScannerController? _controller;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _scanned = true);
    await _controller?.stop();

    final raw = barcode!.rawValue!;
    // Try to parse encoded transfer data from URL
    PatientTransfer? transfer;
    if (raw.contains('?data=')) {
      final encoded = raw.split('?data=').last;
      transfer = PatientTransfer.fromBase64(encoded);
    }
    // Fallback: try direct base64
    transfer ??= PatientTransfer.fromBase64(raw);

    if (transfer == null) {
      // Try by ID from URL
      final id = raw.split('/').last.split('?').first;
      transfer = await TransferService.getById(id);
    }

    if (!mounted) return;

    if (transfer != null) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ReviewScreen(transfer: transfer!)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid QR code or transfer not found',
              style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.critical,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _scanned = false);
      _controller?.start();
    }
  }

  // Demo: simulate scanning first transfer in storage
  Future<void> _simulateScan() async {
    final all = await TransferService.getAll();
    if (all.isNotEmpty && mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ReviewScreen(transfer: all.first)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dark overlay with cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.55), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(color: Colors.transparent),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scan frame corners
          Center(
            child: SizedBox(
              width: 260, height: 260,
              child: Stack(
                children: [
                  // TL
                  Positioned(top: 0, left: 0, child: _Corner(top: true, left: true)),
                  // TR
                  Positioned(top: 0, right: 0, child: _Corner(top: true, left: false)),
                  // BL
                  Positioned(bottom: 0, left: 0, child: _Corner(top: false, left: true)),
                  // BR
                  Positioned(bottom: 0, right: 0, child: _Corner(top: false, left: false)),
                  // Scan line
                  _ScanLine(),
                ],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Scan Transfer QR',
                      style: GoogleFonts.dmSans(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _controller?.toggleTorch(),
                    icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white70, size: 24),
                  ),
                ],
              ),
            ),
          ),

          // Bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Text('Align QR code within the frame',
                        style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _simulateScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Demo: Simulate Scan →',
                            style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool top;
  final bool left;
  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          left: left ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          right: !left ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: (top && left) ? const Radius.circular(12) : Radius.zero,
          topRight: (top && !left) ? const Radius.circular(12) : Radius.zero,
          bottomLeft: (!top && left) ? const Radius.circular(12) : Radius.zero,
          bottomRight: (!top && !left) ? const Radius.circular(12) : Radius.zero,
        ),
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.1, end: 0.85).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        top: 260 * _anim.value,
        left: 8, right: 8,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.primary,
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}
