const String legalPublicBaseUrl = String.fromEnvironment(
  'LEGAL_PUBLIC_BASE_URL',
  defaultValue: 'https://youbook.civiapp.it',
);

const String legalTermsVersion = 'terms-2026-06-05';
const String legalPrivacyVersion = 'privacy-2026-06-01';

Uri get legalPrivacyUri => Uri.parse('$legalPublicBaseUrl/privacy');
Uri get legalTermsUri => Uri.parse('$legalPublicBaseUrl/termini');
