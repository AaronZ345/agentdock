#!/bin/bash
# 编译并打包成 build/AgentDock.app（ad-hoc 签名）
set -e
cd "$(dirname "$0")"
APP=build/AgentDock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/* "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"
swiftc -O -swift-version 5 -lsqlite3 -o "$APP/Contents/MacOS/AgentDock" Sources/*.swift
codesign --force --sign "AgentDock Local Signing" "$APP"
echo "built $APP"
