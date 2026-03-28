#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 Building DiffTool..."
swift build -c release

echo "📦 Creating app bundle..."
APP="DiffTool.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/DiffTool "$APP/Contents/MacOS/DiffTool"

# Create icon if icns exists
if [ -f DiffTool.icns ]; then
    cp DiffTool.icns "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>DiffTool</string>
    <key>CFBundleDisplayName</key>
    <string>DiffTool</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.difftool</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>DiffTool</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
EOF

echo "✅ Built: $(pwd)/$APP"
echo ""
echo "Install to Applications:"
echo "  cp -r DiffTool.app /Applications/"
echo ""
echo "Run:"
echo "  open DiffTool.app"
echo "  open DiffTool.app --args /path/left /path/right"
