/// KoruBeni kullanıcı profil modeli.
/// Firestore `users` koleksiyonundaki doküman yapısını temsil eder.
class UserProfile {
  final String uid;
  final String? phone;
  final String? displayName;
  final String? email;
  final String? fcmToken;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    this.phone,
    this.displayName,
    this.email,
    this.fcmToken,
    this.lastActiveAt,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      phone: json['phone'] as String?,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      fcmToken: json['fcmToken'] as String?,
      lastActiveAt: _parseTimestamp(json['lastActiveAt']),
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'phone': phone,
        'displayName': displayName,
        'email': email,
        'fcmToken': fcmToken,
        if (lastActiveAt != null)
          'lastActiveAt': lastActiveAt!.toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  UserProfile copyWith({
    String? uid,
    String? phone,
    String? displayName,
    String? email,
    String? fcmToken,
    DateTime? lastActiveAt,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      fcmToken: fcmToken ?? this.fcmToken,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    // Firestore Timestamp has a toDate() method
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'UserProfile(uid: $uid, phone: $phone, displayName: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
