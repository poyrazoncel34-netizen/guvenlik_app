import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

class DeviceSecurityService {
  Future<bool> isCompromised() async {
    try {
      return await FlutterJailbreakDetection.jailbroken;
    } catch (e) {
      return false;
    }
  }
}
