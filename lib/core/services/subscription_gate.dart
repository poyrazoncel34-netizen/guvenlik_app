class SubscriptionGate {
  SubscriptionGate._();
  static const int freeContactLimit = 1;
  static bool canAddContact({required int currentCount, required bool isPro}) {
    if (isPro) return true;
    return currentCount < freeContactLimit;
  }
  static bool canUseProFeature({required bool isPro}) => isPro;
}
