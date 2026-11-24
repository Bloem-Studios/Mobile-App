#!/usr/bin/env bash
# Build Bloem's internal iOS app (APP_VARIANT=bloem, see variant.js) and install it on an iPhone.
#
#   scripts/bloem/ios-install.sh [--no-install] [device-udid]
#
# Release configuration, so the JavaScript is bundled in and no Metro server is needed. Signed
# for development by Bloem's Apple team with automatic provisioning, which registers the app
# ids and app group on first run. With no UDID it installs on the first paired physical iPhone.
#
# codesign needs the login keychain, so run it from a logged-in Mac session; over SSH, wrap it
# in ~/bin/gui-run. Needs pnpm, CocoaPods and Xcode signed in to the team's account.
set -euo pipefail
cd "$(dirname "$0")/../.."

install=1
if [[ "${1:-}" == "--no-install" ]]; then
  install=0
  shift
fi
device="${1:-}"

export APP_VARIANT=bloem
export CI=1
team=$(node -p "require('./scripts/bloem/variant').APPLE_TEAM_ID")
build_dir=ios/build
log="${TMPDIR:-/tmp}/tracearr-ios-build-$(date +%Y%m%d-%H%M%S).log"

pnpm install --frozen-lockfile
npx expo prebuild --platform ios --clean --no-install
(cd ios && pod install)

echo "Building (log: $log)"
if ! xcodebuild \
  -workspace ios/Tracearr.xcworkspace \
  -scheme Tracearr \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$build_dir" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$team" \
  CODE_SIGN_STYLE=Automatic \
  build >"$log" 2>&1; then
  grep -E "error:|\*\* BUILD FAILED" "$log" | head -40 || tail -40 "$log"
  exit 1
fi

app="$build_dir/Build/Products/Release-iphoneos/Tracearr.app"
echo "Built $app ($(git rev-parse --short HEAD))"
[[ $install == 1 ]] || exit 0

if [[ -z "$device" ]]; then
  devices=$(mktemp)
  xcrun devicectl list devices --json-output "$devices" >/dev/null
  device=$(node -e '
    const { result } = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const phone = result.devices.find(
      (d) =>
        d.hardwareProperties?.reality === "physical" &&
        d.hardwareProperties?.platform === "iOS" &&
        d.connectionProperties?.pairingState === "paired"
    );
    process.stdout.write(phone?.hardwareProperties?.udid ?? "");
  ' "$devices")
  rm -f "$devices"
  [[ -n "$device" ]] || { echo "No paired iPhone found; pass a UDID" >&2; exit 1; }
fi

xcrun devicectl device install app --device "$device" "$app"
