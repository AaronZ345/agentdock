#!/bin/bash
# 打包成可以发给别人的安装镜像：dist/AgentDock-<版本>.dmg
# - Apple 芯片和 Intel 通用（两种架构各编一遍再合并）
# - 用本机的“AgentDock Local Signing”证书签名：对方更新版本后辅助功能权限不用重开
# - 镜像里有 AgentDock.app、“应用程序”快捷方式和安装说明
set -e
cd "$(dirname "$0")"
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
rm -rf dist/stage dist/obj
mkdir -p dist/stage/AgentDock.app/Contents/MacOS dist/stage/AgentDock.app/Contents/Resources dist/obj
APP=dist/stage/AgentDock.app
cp Resources/* "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos14 -lsqlite3 -o dist/obj/AgentDock-$arch Sources/*.swift
done
lipo -create -output "$APP/Contents/MacOS/AgentDock" dist/obj/AgentDock-arm64 dist/obj/AgentDock-x86_64
rm -rf dist/obj
codesign --force --sign "AgentDock Local Signing" "$APP"
cp packaging/安装说明.txt dist/stage/
ln -s /Applications dist/stage/Applications
rm -f "dist/AgentDock-$VER.dmg"
hdiutil create -volname "AgentDock $VER" -srcfolder dist/stage -fs HFS+ -format UDZO -ov "dist/AgentDock-$VER.dmg" >/dev/null
rm -rf dist/stage
echo "打好了：dist/AgentDock-$VER.dmg"
