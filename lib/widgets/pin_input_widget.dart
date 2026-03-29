import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// A 4-box security PIN input widget (inspired by OTP fields).
/// [onCompleted] is called with the 4-digit PIN when all boxes are filled.
class PinInputWidget extends StatefulWidget {
  final void Function(String pin) onCompleted;
  final Color accentColor;
  final bool obscure;

  const PinInputWidget({
    super.key,
    required this.onCompleted,
    this.accentColor = AppColors.accent,
    this.obscure = true,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste — distribute digits
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < 4 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes[3].requestFocus();
      _tryComplete();
      return;
    }
    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      // Backspace — move back
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    _tryComplete();
  }

  void _tryComplete() {
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length == 4 && pin.split('').every((d) => RegExp(r'[0-9]').hasMatch(d))) {
      widget.onCompleted(pin);
    }
  }

  void clear() {
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: 52,
              height: 60,
              child: TextFormField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              obscureText: widget.obscure,
              obscuringCharacter: '●',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.spaceMono(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: widget.accentColor, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (v) => _onChanged(i, v),
              onTap: () => _controllers[i].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[i].text.length),
            ),
          ),
        ),
        );
      }),
    );
  }
}
