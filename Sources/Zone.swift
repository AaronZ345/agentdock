import Foundation

/// 全应用统一用系统时区（“系统设置 → 日期与时间”里选的那个），不受环境变量 TZ 影响：
/// 从终端带着 TZ 启动时 TimeZone.current 会跟着变，显示的时间就和系统时钟对不上
let appZone: TimeZone = {
    guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: "/etc/localtime"),
          let id = zoneIdentifier(fromLocaltimeTarget: target), let zone = TimeZone(identifier: id) else { return .current }
    return zone
}()

/// /etc/localtime 指向 /var/db/timezone/zoneinfo/<时区 id>，从链接目标里取出时区 id；取不出来返回 nil
func zoneIdentifier(fromLocaltimeTarget target: String) -> String? {
    guard let r = target.range(of: "zoneinfo/"), r.upperBound < target.endIndex else { return nil }
    return String(target[r.upperBound...])
}
