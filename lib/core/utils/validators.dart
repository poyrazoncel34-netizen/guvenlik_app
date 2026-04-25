class Validators {
  static bool isValidPin(String value) =>
      RegExp(r'^\d{4}$').hasMatch(value) && !isWeakPin(value);

  static bool isWeakPin(String value) {
    if (!RegExp(r'^\d{4}$').hasMatch(value)) return true;
    const blocked = {
      '0000',
      '1111',
      '2222',
      '3333',
      '4444',
      '5555',
      '6666',
      '7777',
      '8888',
      '9999',
      '1234',
      '4321',
      '1122',
      '1212',
      '2580',
      '0852',
    };
    if (blocked.contains(value)) return true;
    if (RegExp(r'^(\d)\1{3}$').hasMatch(value)) return true;
    if (RegExp(r'^(\d{2})\1$').hasMatch(value)) return true;

    final digits = value.split('').map(int.parse).toList();
    final ascending = List.generate(
      digits.length - 1,
      (index) => digits[index + 1] - digits[index],
    ).every((diff) => diff == 1);
    final descending = List.generate(
      digits.length - 1,
      (index) => digits[index] - digits[index + 1],
    ).every((diff) => diff == 1);
    return ascending || descending;
  }

  static bool isValidEmail(String value) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value);
  }

  static bool isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }
}
