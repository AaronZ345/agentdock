#!/bin/bash
# 一键安装：编译、装到 /Applications、登记到系统，然后打开
set -e
cd "$(dirname "$0")"
./build.sh
pkill -f "AgentDock.app/Contents/MacOS/AgentDock$" 2>/dev/null || true
sleep 1
rm -rf /Applications/AgentDock.app
cp -R build/AgentDock.app /Applications/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/AgentDock.app
# 不带终端里的 TZ 之类环境变量启动
env -u TZ open /Applications/AgentDock.app
echo "已安装到 /Applications/AgentDock.app"
