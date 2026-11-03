class LaunchConfig {
  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://dermoha.github.io/Sophis/privacy.html',
  );
  static const supportUrl = String.fromEnvironment(
    'SUPPORT_URL',
    defaultValue: 'https://dermoha.github.io/Sophis/support.html',
  );
  static const termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://dermoha.github.io/Sophis/terms.html',
  );

  static bool get hasRequiredUrls =>
      Uri.tryParse(privacyPolicyUrl)?.hasScheme == true &&
      Uri.tryParse(supportUrl)?.hasScheme == true &&
      Uri.tryParse(termsUrl)?.hasScheme == true;
}
