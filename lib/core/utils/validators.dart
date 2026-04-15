class Validators {
  static bool isValidPin(String value) =>
      RegExp(r'^\d{4}$').hasMatch(value);

  static bool isValidEmail(String value) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value);
  }

  static bool isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }
}
