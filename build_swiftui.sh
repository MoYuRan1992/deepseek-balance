#!/bin/bash
set -e

# ==========================================
# DeepSeek Balance macOS 构建脚本
# 编译 SwiftUI 源码 → .app bundle → 精美 .dmg
# ==========================================

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DeepSeek Balance"
EXEC_NAME="DeepSeek Balance"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
DMG_NAME="DeepSeek Balance.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"
DMG_TMP="$BUILD_DIR/dmg_temp.dmg"
DMG_MOUNT="/Volumes/$APP_NAME"

SWIFT_SOURCES=(
    "Constants.swift"
    "Models.swift"
    "MenuBarView.swift"
    "Services.swift"
    "SettingsView.swift"
    "UpdatePromptView.swift"
    "AppDelegate.swift"
    "main.swift"
)

DMG_WIN_WIDTH=540
DMG_WIN_HEIGHT=360

echo "=== 清理旧构建产物 ==="
rm -rf "$BUILD_DIR"
rm -f "$DMG_PATH"
mkdir -p "$BUILD_DIR"

# ---------- 生成 DMG 背景图 ----------
echo "=== 生成 DMG 背景图 ==="
cat > /tmp/dmg_background.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="540" height="360">
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="75%">
      <stop offset="0%" stop-color="#5c5c7a"/>
      <stop offset="100%" stop-color="#3a3a55"/>
    </radialGradient>
    <linearGradient id="glow" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="rgba(0,210,255,0)"/>
      <stop offset="50%" stop-color="#00d2ff" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="rgba(122,44,255,0)"/>
    </linearGradient>
  </defs>
  <rect width="540" height="360" fill="url(#bg)"/>
  <g stroke="rgba(0,210,255,0.08)" stroke-width="1">
    <line x1="0" y1="72" x2="540" y2="72"/>
    <line x1="0" y1="144" x2="540" y2="144"/>
    <line x1="0" y1="216" x2="540" y2="216"/>
    <line x1="0" y1="288" x2="540" y2="288"/>
  </g>
  <g stroke="rgba(122,44,255,0.08)" stroke-width="1">
    <line x1="135" y1="0" x2="135" y2="360"/>
    <line x1="270" y1="0" x2="270" y2="360"/>
    <line x1="405" y1="0" x2="405" y2="360"/>
  </g>
  <rect y="176" width="540" height="4" fill="url(#glow)" opacity="0.5"/>
  <circle cx="495" cy="45" r="22" fill="none" stroke="#00d2ff" stroke-width="1" opacity="0.2"/>
  <circle cx="495" cy="45" r="7" fill="#7a2cff" opacity="0.3"/>
  <circle cx="45" cy="315" r="13" fill="none" stroke="#7a2cff" stroke-width="1" opacity="0.15"/>
</svg>
SVGEOF

qlmanage -t -s 540 -o /tmp /tmp/dmg_background.svg > /dev/null 2>&1
cp /tmp/dmg_background.svg.png "$BUILD_DIR/background.png"

# ---------- 编译 Swift ----------
echo "=== 创建 .app 目录结构 ==="
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR/locales"

echo "=== 生成应用图标 ==="
if [ -f "$PROJECT_DIR/AppIcon.svg" ]; then
    ICONSET="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    # 用 qlmanage 渲染 SVG 为高分辨率 PNG
    qlmanage -t -s 1024 -o /tmp "$PROJECT_DIR/AppIcon.svg" > /dev/null 2>&1
    SRC="/tmp/AppIcon.svg.png"
    if [ -f "$SRC" ]; then
        sips -z 16 16 "$SRC" --out "$ICONSET/icon_16x16.png"
        sips -z 32 32 "$SRC" --out "$ICONSET/icon_16x16@2x.png"
        sips -z 32 32 "$SRC" --out "$ICONSET/icon_32x32.png"
        sips -z 64 64 "$SRC" --out "$ICONSET/icon_32x32@2x.png"
        sips -z 128 128 "$SRC" --out "$ICONSET/icon_128x128.png"
        sips -z 256 256 "$SRC" --out "$ICONSET/icon_128x128@2x.png"
        sips -z 256 256 "$SRC" --out "$ICONSET/icon_256x256.png"
        sips -z 512 512 "$SRC" --out "$ICONSET/icon_256x256@2x.png"
        sips -z 512 512 "$SRC" --out "$ICONSET/icon_512x512.png"
        sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png"
        iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
        cp "$RESOURCES_DIR/AppIcon.icns" "$PROJECT_DIR/AppIcon.icns"
        rm -f "$SRC"
        echo "图标已生成: AppIcon.icns"
    fi
fi

echo "=== 复制资源文件 ==="
cp "$PROJECT_DIR/locales/en.json" "$RESOURCES_DIR/locales/"
cp "$PROJECT_DIR/locales/ru.json" "$RESOURCES_DIR/locales/"
cp "$PROJECT_DIR/locales/zh-CN.json" "$RESOURCES_DIR/locales/"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS/"

SRC_ARGS=()
for src in "${SWIFT_SOURCES[@]}"; do
    SRC_ARGS+=("$PROJECT_DIR/SwiftUI/$src")
done

echo "=== 编译 arm64 ==="
xcrun swiftc \
    -target arm64-apple-macosx12.0 \
    -O \
    -framework Cocoa \
    -framework SwiftUI \
    -framework UserNotifications \
    -o "$BUILD_DIR/arm64_$EXEC_NAME" \
    "${SRC_ARGS[@]}"

echo "=== 编译 x86_64 ==="
xcrun swiftc \
    -target x86_64-apple-macosx12.0 \
    -O \
    -framework Cocoa \
    -framework SwiftUI \
    -framework UserNotifications \
    -o "$BUILD_DIR/x86_64_$EXEC_NAME" \
    "${SRC_ARGS[@]}"

echo "=== 合并通用二进制 ==="
lipo "$BUILD_DIR/arm64_$EXEC_NAME" "$BUILD_DIR/x86_64_$EXEC_NAME" -create -output "$MACOS_DIR/$EXEC_NAME"
rm -f "$BUILD_DIR/arm64_$EXEC_NAME" "$BUILD_DIR/x86_64_$EXEC_NAME"

# ---------- 创建 DMG ----------
echo "=== 创建空白 DMG 并挂载 ==="
hdiutil create \
    -size 20m \
    -fs HFS+ \
    -volname "$APP_NAME" \
    -attach \
    -ov \
    "$DMG_TMP" > /dev/null
sleep 1

echo "=== 复制文件 ==="
cp -R "$APP_BUNDLE" "$DMG_MOUNT/"
ln -s /Applications "$DMG_MOUNT/Applications"

# 复制背景图到隐藏文件夹
mkdir -p "$DMG_MOUNT/.background"
cp "$BUILD_DIR/background.png" "$DMG_MOUNT/.background/background.png"
/usr/bin/SetFile -a V "$DMG_MOUNT/.background" 2>/dev/null || xcrun SetFile -a V "$DMG_MOUNT/.background" 2>/dev/null || true

# 用 AppleScript 设置 Finder 窗口样式
osascript <<EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, $((100 + DMG_WIN_WIDTH)), $((100 + DMG_WIN_HEIGHT))}

        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 112
        set text size of theViewOptions to 14
        set background picture of theViewOptions to file ".background:background.png"

        set position of item "$APP_NAME.app" to {180, 124}
        set position of item "Applications" to {360, 124}

        update without registering applications
        delay 1
    end tell
end tell
EOF

# 给 Finder 时间将窗口属性写入 .DS_Store
sleep 3

echo "=== 卸载 DMG ==="
sleep 1
hdiutil detach "$DMG_MOUNT"

# 压缩 DMG
echo "=== 压缩 DMG ==="
hdiutil convert "$DMG_TMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"
rm -f "$DMG_TMP"

echo ""
echo "=== 构建完成 ==="
echo "DMG 路径: $DMG_PATH"
ls -lh "$DMG_PATH"
