import 'package:safe_device/safe_device.dart';

class DeviceSecurityService {
  Future<bool> isCompromised() async {
    try {
      return await SafeDevice.isJailBroken;
    } catch (e) {
      return false;
    }
  }
}
