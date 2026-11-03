#!/usr/bin/env bash
set -euo pipefail

SOPHIS_PRIVACY_POLICY_URL="${SOPHIS_PRIVACY_POLICY_URL:-https://dermoha.github.io/Sophis/privacy.html}"
SOPHIS_SUPPORT_URL="${SOPHIS_SUPPORT_URL:-https://dermoha.github.io/Sophis/support.html}"
SOPHIS_TERMS_URL="${SOPHIS_TERMS_URL:-https://dermoha.github.io/Sophis/terms.html}"

usage() {
  cat <<'EOF'
Build a signed Sophis iOS IPA for TestFlight.

Optional URL overrides (defaults to the published Sophis GitHub Pages site):
  SOPHIS_PRIVACY_POLICY_URL  Public HTTPS privacy policy URL
  SOPHIS_SUPPORT_URL         Public HTTPS support URL
  SOPHIS_TERMS_URL           Public HTTPS terms URL

Usage:
  scripts/build_testflight.sh [build-number]

The version name comes from pubspec.yaml. The build number defaults to the
current Unix timestamp and can be supplied explicitly for a release.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

for variable in SOPHIS_PRIVACY_POLICY_URL SOPHIS_SUPPORT_URL SOPHIS_TERMS_URL; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required environment variable: ${variable}" >&2
    usage >&2
    exit 2
  fi
  if [[ "${!variable}" != https://* ]]; then
    echo "${variable} must be a public HTTPS URL." >&2
    exit 2
  fi
  case "${!variable}" in
    *example.com*|*YOUR-DOMAIN*|*placeholder*)
      echo "${variable} must point to a published Sophis page, not a placeholder." >&2
      exit 2
      ;;
  esac
done

build_number="${1:-$(date +%s)}"
if [[ ! "${build_number}" =~ ^[0-9]+$ ]]; then
  echo "Build number must contain digits only." >&2
  exit 2
fi

version="$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml | head -n 1)"
if [[ -z "${version}" ]]; then
  echo "Could not read the app version from pubspec.yaml." >&2
  exit 2
fi

flutter build ipa \
  --release \
  --no-tree-shake-icons \
  --build-name="${version}" \
  --build-number="${build_number}" \
  --dart-define="PRIVACY_POLICY_URL=${SOPHIS_PRIVACY_POLICY_URL}" \
  --dart-define="SUPPORT_URL=${SOPHIS_SUPPORT_URL}" \
  --dart-define="TERMS_URL=${SOPHIS_TERMS_URL}"

echo "IPA created under build/ios/ipa/. Upload it with Transporter or Xcode Organizer."
