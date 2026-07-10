class LaunchConfig {
  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
  );
  static const supportUrl = String.fromEnvironment('SUPPORT_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');

  static bool get hasRequiredUrls =>
      Uri.tryParse(privacyPolicyUrl)?.hasScheme == true &&
      Uri.tryParse(supportUrl)?.hasScheme == true &&
      Uri.tryParse(termsUrl)?.hasScheme == true;
}
