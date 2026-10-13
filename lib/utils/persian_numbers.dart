import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Converts every ASCII digit (0-9) in [input] to its Persian/Farsi digit
/// equivalent. Used everywhere a number reaches the UI (coin balances,
/// scores, ranks, timers, prices, round numbers) — Persian UI convention is
/// Farsi digits throughout, not Western ones. Safe to call on any string;
/// non-digit characters (٪, ':', separators, RTL marks) pass through
/// unchanged, so `'12:05'.toPersianDigits()` → `'۱۲:۰۵'`.
extension PersianDigits on String {
  String toPersianDigits() {
    final buffer = StringBuffer();
    for (final rune in runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.write(_persianDigits[rune - 0x30]);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}

/// Reverse of [toPersianDigits]: turns Persian (۰-۹) and Arabic-Indic
/// (٠-٩) digits back into ASCII, leaving everything else alone. Use before
/// sending user-typed numeric input to the server or validating it.
extension AsciiDigits on String {
  String toAsciiDigits() {
    final buffer = StringBuffer();
    for (final rune in runes) {
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + (rune - 0x06F0)); // Persian
      } else if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + (rune - 0x0660)); // Arabic-Indic
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}

/// Convenience for the common `value.toString()` + convert pattern.
extension PersianDigitsNum on num {
  String toPersianString() => toString().toPersianDigits();

  /// Persian digits with a thousands separator every 3 digits from the
  /// right (`٬`, U+066C — the Farsi grouping mark). For an integer value:
  /// `1500000` → `'۱٬۵۰۰٬۰۰۰'`. A fractional part (if any) is left ungrouped.
  /// Use for coin balances, prices, scores — anywhere a big number is shown.
  String toPersianStringGrouped() {
    final negative = this < 0;
    final parts = abs().toString().split('.');
    var intPart = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('٬');
      buffer.write(intPart[i]);
    }
    var out = buffer.toString();
    if (parts.length > 1) out = '$out.${parts[1]}';
    if (negative) out = '-$out';
    return out.toPersianDigits();
  }
}

/// A [TextInputFormatter] that displays every ASCII/Arabic digit the user
/// types as a Persian digit, so a numeric input field visually matches the
/// rest of the Persian UI. The controller's `.text` then holds Persian
/// digits — call `.toAsciiDigits()` on it before validating or sending.
class PersianDigitInputFormatter extends TextInputFormatter {
  const PersianDigitInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final converted = newValue.text.toAsciiDigits().toPersianDigits();
    if (converted == newValue.text) return newValue;
    return newValue.copyWith(
      text: converted,
      // Length is unchanged (1:1 digit swap), so keep the selection as-is.
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

/// Drop-in `TextField.buildCounter` that renders the "x/y" character
/// counter with Persian digits instead of Flutter's default Western-digit
/// counter. Usage: `TextField(maxLength: 20, buildCounter: persianCounter)`.
Widget? persianCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) {
  final text = maxLength != null
      ? '${currentLength.toPersianString()}/${maxLength.toPersianString()}'
      : currentLength.toPersianString();
  return Text(text, style: Theme.of(context).textTheme.bodySmall);
}
