import 'package:flutter/material.dart';
import '../utils/persian_numbers.dart';

/// Drop-in replacement for [Text] that renders every ASCII digit in Persian
/// (۰-۹). Use it everywhere in the app instead of [Text] so numbers —
/// scores, counts, timers, prices, ranks — always match the Persian UI,
/// without sprinkling `.toPersianString()` at every call site.
///
/// Only the plain-string constructor is Persian-ized; [PText.rich] passes
/// its [InlineSpan] through untouched (callers building a rich span can
/// Persian-ize their own text parts).
class PText extends StatelessWidget {
  const PText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.textScaler,
  }) : _textSpan = null;

  const PText.rich(
    InlineSpan textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.textScaler,
  })  : data = null,
        _textSpan = textSpan;

  final String? data;
  final InlineSpan? _textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    if (_textSpan != null) {
      return Text.rich(
        _textSpan,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
        textScaler: textScaler,
      );
    }
    return Text(
      (data ?? '').toPersianDigits(),
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
      textScaler: textScaler,
    );
  }
}
