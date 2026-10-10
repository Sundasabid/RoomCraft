import 'dart:math';

/// No I, O, 0 or 1, so a code can be read aloud without confusion.
const shareAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const shareCodeLength = 6;
final shareCodePattern = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

final _random = Random.secure();

String newShareCode() => List.generate(
  shareCodeLength,
  (_) => shareAlphabet[_random.nextInt(shareAlphabet.length)],
).join();

/// Uppercases typed or pasted text and drops spaces and dashes.
String normaliseCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// True when every character is from the alphabet (length not checked).
bool usesShareAlphabet(String code) =>
    code.split('').every(shareAlphabet.contains);

bool isShareCode(String code) => shareCodePattern.hasMatch(code);
