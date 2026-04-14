#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"
ANDROID_DIR="$ROOT_DIR/android"
LOCAL_PROPERTIES_FILE="$ANDROID_DIR/local.properties"
RELEASE_VERSION_FILE="$ANDROID_DIR/release-version.properties"
OUTPUT_BUNDLE="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"
REPO_NAME="$(basename "$ROOT_DIR")"

if [[ ! -f "$PUBSPEC_FILE" ]]; then
  echo "Missing pubspec.yaml at $PUBSPEC_FILE" >&2
  exit 1
fi

if [[ ! -d "$ANDROID_DIR" ]]; then
  echo "Missing Android project at $ANDROID_DIR" >&2
  exit 1
fi

read -r VERSION_NAME CURRENT_CODE < <(
  perl -ne 'print "$1 $2\n" if /^version:\s*([0-9A-Za-z._-]+)\+([0-9]+)/' "$PUBSPEC_FILE"
)

if [[ -z "${VERSION_NAME:-}" || -z "${CURRENT_CODE:-}" ]]; then
  echo "Could not parse version from $PUBSPEC_FILE" >&2
  exit 1
fi

NEXT_CODE=$((CURRENT_CODE + 1))
NEXT_VERSION="${VERSION_NAME}+${NEXT_CODE}"

perl -0pi -e "s/^version:\\s*.*\$/version: ${NEXT_VERSION}/m" "$PUBSPEC_FILE"

touch "$LOCAL_PROPERTIES_FILE"

if grep -q '^flutter.versionName=' "$LOCAL_PROPERTIES_FILE"; then
  perl -0pi -e "s/^flutter\\.versionName=.*/flutter.versionName=${VERSION_NAME}/m" "$LOCAL_PROPERTIES_FILE"
else
  printf '\nflutter.versionName=%s\n' "$VERSION_NAME" >> "$LOCAL_PROPERTIES_FILE"
fi

if grep -q '^flutter.versionCode=' "$LOCAL_PROPERTIES_FILE"; then
  perl -0pi -e "s/^flutter\\.versionCode=.*/flutter.versionCode=${NEXT_CODE}/m" "$LOCAL_PROPERTIES_FILE"
else
  printf 'flutter.versionCode=%s\n' "$NEXT_CODE" >> "$LOCAL_PROPERTIES_FILE"
fi

cat > "$RELEASE_VERSION_FILE" <<EOF
versionName=${VERSION_NAME}
versionCode=${NEXT_CODE}
EOF

(
  cd "$ANDROID_DIR"
  ./gradlew :app:bundleRelease
)

if [[ ! -f "$OUTPUT_BUNDLE" ]]; then
  echo "Expected bundle not found at $OUTPUT_BUNDLE" >&2
  exit 1
fi

DESTINATION_BUNDLE="$DESKTOP_DIR/${REPO_NAME}-${NEXT_VERSION}-release.aab"
cp "$OUTPUT_BUNDLE" "$DESTINATION_BUNDLE"

echo "Built $DESTINATION_BUNDLE"
