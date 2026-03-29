import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transfer.dart';
import '../theme/app_theme.dart';

class TransferStatusTracker extends StatefulWidget {
  final PatientTransfer transfer;
  const TransferStatusTracker({super.key, required this.transfer});

  @override
  State<TransferStatusTracker> createState() => _TransferStatusTrackerState();
}

class _TransferStatusTrackerState extends State<TransferStatusTracker> {
  Timer? _timer;
  int _remaining = 0; // seconds remaining

  static const _stages = [
    _Stage('created',   'Created',    Icons.assignment_turned_in_rounded),
    _Stage('en_route',  'En Route',   Icons.local_shipping_rounded),
    _Stage('received',  'Arrived',    Icons.local_hospital_rounded),
    _Stage('completed', 'Completed',  Icons.check_circle_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    if (widget.transfer.status != 'en_route') return;
    final dispatch = widget.transfer.dispatchTime;
    if (dispatch == null) return;
    final etaSecs = widget.transfer.etaMinutes * 60;
    final elapsed = DateTime.now().difference(dispatch).inSeconds;
    _remaining = (etaSecs - elapsed).clamp(0, etaSecs);

    if (_remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_remaining > 0) _remaining--;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _stageIndex(String status) {
    switch (status) {
      case 'en_route':  return 1;
      case 'received':  return 2;
      case 'completed': return 3;
      default:          return 0; // pending / created
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _stageIndex(widget.transfer.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.timeline_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('TRANSFER STATUS',
                style: GoogleFonts.dmSans(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.muted, letterSpacing: 1.3)),
            const Spacer(),
            _StatusBadge(widget.transfer.status),
          ]),

          const SizedBox(height: 16),

          // Stage dots + connectors
          Row(
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final leftStageIdx = i ~/ 2;
                final isCompleted = currentIdx > leftStageIdx;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 3,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.accent : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final stageIdx = i ~/ 2;
              final stage = _stages[stageIdx];
              final isActive = stageIdx == currentIdx;
              final isPast   = stageIdx < currentIdx;

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: isActive ? 42 : 36,
                    height: isActive ? 42 : 36,
                    decoration: BoxDecoration(
                      color: isPast
                          ? AppColors.accent
                          : isActive
                              ? AppColors.primary
                              : AppColors.bg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPast
                            ? AppColors.accent
                            : isActive
                                ? AppColors.primary
                                : AppColors.border,
                        width: isActive ? 2.5 : 1.5,
                      ),
                      boxShadow: isActive
                          ? [BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 10, spreadRadius: 1)]
                          : [],
                    ),
                    child: Icon(
                      stage.icon,
                      size: isActive ? 20 : 16,
                      color: (isPast || isActive) ? Colors.white : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stage.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                ],
              );
            }),
          ),

          // ETA counter (only while en route)
          if (widget.transfer.status == 'en_route') ...[
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _remaining <= 120
                    ? AppColors.redLight
                    : AppColors.blueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.timer_rounded,
                    size: 16,
                    color: _remaining <= 120 ? AppColors.critical : AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _remaining <= 0
                      ? 'Patient should have arrived'
                      : 'ETA: ${_formatTime(_remaining)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _remaining <= 120 ? AppColors.critical : AppColors.primary,
                  ),
                ),
                const Spacer(),
                if (_remaining > 0)
                  Text(
                    _remaining <= 120 ? '⚠ Arriving soon!' : '',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.critical,
                        fontWeight: FontWeight.w700),
                  ),
              ]),
            ),
          ],

          // Dispatch info
          if (widget.transfer.dispatchTime != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.directions_run_rounded, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('Dispatched: ${_formatDispatch(widget.transfer.dispatchTime!)}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
            ]),
          ],
        ],
      ),
    );
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDispatch(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }
}

// ── Status badge chip ────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _color {
    switch (status) {
      case 'en_route':  return const Color(0xFF6366F1);
      case 'received':  return AppColors.accent;
      case 'completed': return AppColors.accent;
      default:          return AppColors.muted;
    }
  }

  Color get _bg {
    switch (status) {
      case 'en_route':  return const Color(0xFFEEF2FF);
      case 'received':  return AppColors.greenLight;
      case 'completed': return AppColors.greenLight;
      default:          return AppColors.bg;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':   return '⏳ Pending';
      case 'en_route':  return '🚑 En Route';
      case 'received':  return '✅ Arrived';
      case 'completed': return '✅ Completed';
      default:          return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(_label,
          style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: _color)),
    );
  }
}

// ── Internal stage data ──────────────────────────────────────────────────────
class _Stage {
  final String key;
  final String label;
  final IconData icon;
  const _Stage(this.key, this.label, this.icon);
}
