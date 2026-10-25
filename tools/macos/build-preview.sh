#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="${LABS_MAC_OUTPUT:-$ROOT/artifacts/macos-preview}"
APP="$OUT/Achievement Labs.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
python3 mobile/tools/prepare_360.py
dotnet publish src/AchievementLabs.Desktop/AchievementLabs.Desktop.csproj -c Release -r osx-arm64 --self-contained true -p:LabsMacOS=true -p:PublishSingleFile=false -p:DebugType=None -p:DebugSymbols=false -p:NuGetAudit=false -p:LabsXbox360SigningFile="$ROOT/mobile/Shared360/signing.dat" -o "$APP/Contents/MacOS"
chmod +x "$APP/Contents/MacOS/AchievementLabs"
python3 - "$APP" <<'PY'
from pathlib import Path
import plistlib,sys
app=Path(sys.argv[1]);info={'CFBundleName':'Achievement Labs','CFBundleDisplayName':'Achievement Labs','CFBundleIdentifier':'org.achievementlabs.desktop.macos.preview','CFBundleExecutable':'AchievementLabs','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'1','LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True,'CFBundleIconFile':'AchievementLabs.icns','NSHumanReadableCopyright':'Unofficial Achievement Labs fork; upstream: Achievement-Labs/achievement-labs'}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
ICONSET="$OUT/AchievementLabs.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" src/AchievementLabs.App/Assets/achievement-labs-icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size*2));sips -z "$double" "$double" src/AchievementLabs.App/Assets/achievement-labs-icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AchievementLabs.icns"
cat > "$OUT/entitlements.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.cs.allow-jit</key><true/></dict></plist>
PLIST
# Ad-hoc signing is for local testing only; Developer ID/notarization is a later release step.
while IFS= read -r -d '' binary; do
  if file -b "$binary" | grep -q 'Mach-O'; then codesign --force --sign - --options runtime --entitlements "$OUT/entitlements.plist" "$binary"; fi
done < <(find "$APP/Contents/MacOS" -type f -print0)
codesign --force --sign - --options runtime --entitlements "$OUT/entitlements.plist" "$APP"
codesign --verify --strict --verbose=2 "$APP"
python3 - "$APP" <<'PY'
from pathlib import Path
import sys
app=Path(sys.argv[1]);bad=[p.name for p in app.rglob('*') if p.is_file() and (p.suffix.lower() in {'.con','.profile','.keystore','.p12','.labslink','.cs','.axaml','.pdb','.exe'} or 'keyvault' in p.name.lower())]
assert not bad,bad
print('Verified Mac bundle excludes Windows EXEs, source/debug files and personal-profile/credential stores.')
PY
cp docs/macos-preview.md "$OUT/README.md"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/AchievementLabs-macOS-0.1.0.1-arm64.zip"
(cd "$OUT" && shasum -a 256 AchievementLabs-macOS-0.1.0.1-arm64.zip > SHA256.txt)
echo "Built Apple Silicon Mac preview: $OUT"
