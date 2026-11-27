#!/bin/bash
# 打包成可以发给别人的安装镜像：dist/Convoy-<版本>.dmg
# - Apple 芯片和 Intel 通用（两种架构各编一遍再合并）
# - 用本机的“AgentDock Local Signing”证书签名：对方更新版本后辅助功能权限不用重开
# - 镜像里有 Convoy.app、“应用程序”快捷方式和安装说明
set -e
cd "$(dirname "$0")"
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
rm -rf dist/stage dist/obj
mkdir -p dist/stage/Convoy.app/Contents/MacOS dist/stage/Convoy.app/Contents/Resources dist/obj
APP=dist/stage/Convoy.app
cp Resources/* "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos14 -lsqlite3 -o dist/obj/Convoy-$arch Sources/*.swift
done
lipo -create -output "$APP/Contents/MacOS/Convoy" dist/obj/Convoy-arm64 dist/obj/Convoy-x86_64
rm -rf dist/obj
codesign --force --sign "AgentDock Local Signing" "$APP"
cp packaging/安装说明.txt dist/stage/
cp packaging/Install.txt dist/stage/
cp LICENSE dist/stage/LICENSE.txt
ln -s /Applications dist/stage/Applications
rm -f "dist/Convoy-$VER.dmg"
hdiutil create -volname "Convoy $VER" -srcfolder dist/stage -fs HFS+ -format UDZO -ov "dist/Convoy-$VER.dmg" >/dev/null
rm -rf dist/stage
echo "打好了：dist/Convoy-$VER.dmg"
