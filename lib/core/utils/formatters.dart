class Formatters {
  static String formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return value;
    return '+${digits.substring(0, digits.length)}';
  }
}
