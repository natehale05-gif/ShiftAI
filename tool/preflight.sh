#!/usr/bin/env bash
# Everything that can be checked without Xcode or the Android SDK, run in
# one go. This is not a substitute for the first native build — it is the
# list of things that are annoying to discover halfway through one.
#
#   bash tool/preflight.sh
set -uo pipefail

fail=0
ok()   { printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
warn() { printf '  \033[33mnote\033[0m %s\n' "$1"; }

echo "Dart and tests"
flutter analyze --no-pub >/dev/null 2>&1 && ok "analyzer clean" || bad "flutter analyze"
flutter test --no-pub >/dev/null 2>&1 && ok "tests pass" || bad "flutter test"

echo
echo "Icons"
for f in ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png \
         android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png \
         android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml; do
  [ -f "$f" ] && ok "$(basename "$f")" || bad "missing $f"
done
python3 - <<'PY' && ok "1024 icon is opaque (App Store rejects alpha)" || bad "1024 icon has an alpha channel"
from PIL import Image
import sys
im = Image.open('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
sys.exit(0 if im.mode == 'RGB' else 1)
PY

echo
echo "iOS"
grep -q PrivacyInfo ios/Runner.xcodeproj/project.pbxproj \
  && ok "privacy manifest is in the Xcode project" \
  || bad "PrivacyInfo.xcprivacy is on disk but not in project.pbxproj"
python3 -c "import plistlib;plistlib.load(open('ios/Runner/Info.plist','rb'))" 2>/dev/null \
  && ok "Info.plist parses" || bad "Info.plist is not valid"
python3 -c "import plistlib;plistlib.load(open('ios/Runner/PrivacyInfo.xcprivacy','rb'))" 2>/dev/null \
  && ok "PrivacyInfo.xcprivacy parses" || bad "PrivacyInfo.xcprivacy is not valid"
grep -q "club.shiftai.app" ios/Runner.xcodeproj/project.pbxproj \
  && ok "bundle id set" || bad "bundle id not set"
grep -q "NSLocationWhenInUseUsageDescription" ios/Runner/Info.plist \
  && ok "location usage string set (the local league needs it)" \
  || bad "no NSLocationWhenInUseUsageDescription: asking for location crashes"
grep -q "^Pod::PICKER_AUDIO = false" ios/Podfile 2>/dev/null \
  && ok "file_picker's Apple Music picker is compiled out" \
  || bad "ios/Podfile lost Pod::PICKER_AUDIO = false: the upload asks for an NSAppleMusicUsageDescription (ITMS-90683)"

echo
echo "Home screen widgets"
grep -q "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements" ios/Runner.xcodeproj/project.pbxproj \
  && ok "Runner is wired to its entitlements file" \
  || bad "Runner.entitlements is on disk but not wired into project.pbxproj"
python3 -c "import plistlib;plistlib.load(open('ios/Runner/Runner.entitlements','rb'))" 2>/dev/null \
  && ok "Runner.entitlements parses" || bad "Runner.entitlements is not valid"
for f in ios/ShiftLeaderboardWidgets/ShiftLeaderboardWidgetsBundle.swift \
         ios/ShiftLeaderboardWidgets/Info.plist \
         ios/ShiftLeaderboardWidgets/ShiftLeaderboardWidgets.entitlements; do
  [ -f "$f" ] && ok "$(basename "$f") ready for the Xcode target — see docs/WIDGETS.md" \
    || bad "missing $f"
done

echo
echo "Android"
grep -q 'applicationId = "club.shiftai.app"' android/app/build.gradle.kts \
  && ok "applicationId set" || bad "applicationId not set"
grep -q "android.permission.INTERNET" android/app/src/main/AndroidManifest.xml \
  && ok "INTERNET permission (release builds have none without it)" \
  || bad "no INTERNET permission"
grep -q "android.permission.ACCESS_COARSE_LOCATION" \
  android/app/src/main/AndroidManifest.xml \
  && ok "coarse location permission (the local league needs it)" \
  || bad "no ACCESS_COARSE_LOCATION: sharing a location will silently fail"
for k in fluttersecurestorage filepicker home_widget; do
  grep -q "$k" android/app/proguard-rules.pro \
    && ok "R8 keeps $k" || bad "R8 will strip $k in release"
done
if [ -f android/key.properties ]; then
  ok "key.properties present — release builds will be signed for Play"
else
  warn "no android/key.properties: a release build falls back to the"
  warn "debug key and Play will reject it. See docs/RELEASE.md."
fi

echo
[ "$fail" -eq 0 ] && echo "Ready for the first native build." \
  || echo "Fix the FAILs above first."
exit "$fail"
