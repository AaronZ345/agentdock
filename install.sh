#!/bin/bash
# 一键安装：编译、装到 /Applications、登记到系统，然后打开
set -e
cd "$(dirname "$0")"
./build.sh
pkill -f "Convoy.app/Contents/MacOS/Convoy$" 2>/dev/null || true
sleep 1
rm -rf /Applications/Convoy.app
# 改名前的旧版（AgentDock.app）一起退出并删掉：同一个应用标识，权限和数据都沿用
pkill -f "AgentDock.app/Contents/MacOS/AgentDock$" 2>/dev/null || true
rm -rf /Applications/AgentDock.app
cp -R build/Convoy.app /Applications/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Convoy.app
# 不带终端里的 TZ 之类环境变量启动
env -u TZ open /Applications/Convoy.app
echo "已安装到 /Applications/Convoy.app"
