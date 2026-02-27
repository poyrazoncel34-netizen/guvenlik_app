import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

enum ActivityType {
  emergencyCancelled,
  emergencyTriggered,
  locationShared,
  sirenUsed,
  safetyCheck,
  pinChanged,
  fakeCallUsed,
  contactAdded,
  timelineNote,
  checkIn,
}

class ActivityEvent {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;

  const ActivityEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });

  IconData get icon {
    switch (type) {
      case ActivityType.emergencyCancelled:
        return Icons.cancel_rounded;
      case ActivityType.emergencyTriggered:
        return Icons.sos_rounded;
      case ActivityType.locationShared:
        return Icons.location_on_rounded;
      case ActivityType.sirenUsed:
        return Icons.volume_up_rounded;
      case ActivityType.safetyCheck:
        return Icons.check_circle_rounded;
      case ActivityType.pinChanged:
        return Icons.lock_rounded;
      case ActivityType.fakeCallUsed:
        return Icons.phone_in_talk_rounded;
      case ActivityType.contactAdded:
        return Icons.person_add_rounded;
      case ActivityType.timelineNote:
        return Icons.edit_note_rounded;
      case ActivityType.checkIn:
        return Icons.verified_user_rounded;
    }
  }

  Color get color {
    switch (type) {
      case ActivityType.emergencyCancelled:
        return AppColors.success;
      case ActivityType.emergencyTriggered:
        return AppColors.emergency;
      case ActivityType.locationShared:
        return AppColors.primary;
      case ActivityType.sirenUsed:
        return AppColors.warning;
      case ActivityType.safetyCheck:
        return AppColors.success;
      case ActivityType.pinChanged:
        return AppColors.info;
      case ActivityType.fakeCallUsed:
        return AppColors.primary;
      case ActivityType.contactAdded:
        return AppColors.info;
      case ActivityType.timelineNote:
        return AppColors.accent;
      case ActivityType.checkIn:
        return AppColors.success;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ActivityEvent.fromMap(Map<String, dynamic> map) {
    return ActivityEvent(
      id: map['id'] as String,
      type: ActivityType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ActivityType.safetyCheck,
      ),
      title: map['title'] as String,
      description: map['description'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
