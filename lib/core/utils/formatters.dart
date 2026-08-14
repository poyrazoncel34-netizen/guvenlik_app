class Formatters {
  /// `HH:mm`, zero-padded. Lived as a private method inside map_page.dart, which
  /// is over the project file-size limit; a pure string helper is exactly the
  /// kind of thing that should not be holding an oversize screen open.
  static String clockHm(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return value;
    return '+${digits.substring(0, digits.length)}';
  }
}
