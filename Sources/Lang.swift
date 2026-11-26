import Cocoa

// 界面语言：中文（默认）或英文。启动时读一次，切换后重启应用生效。
// 用法：tr("中文", "English")。只用于 AgentDock 自己的界面文案；
// 匹配原应用界面的文字（Labels.swift）、写进数据里的内部取值（大类状态“进行中”、结论“有效”等）不要翻译

let appLanguageKey = "appLanguage"

/// "zh" 或 "en"
let appLang: String = {
    // 测试和截图用：--lang en / --lang zh 临时指定，不改保存的设置
    let a = CommandLine.arguments
    if let i = a.firstIndex(of: "--lang"), a.count > i + 1, ["zh", "en"].contains(a[i + 1]) { return a[i + 1] }
    return UserDefaults.standard.string(forKey: appLanguageKey) == "en" ? "en" : "zh"
}()

var isEnglish: Bool { appLang == "en" }

@inline(__always)
func tr(_ zh: String, _ en: String) -> String { appLang == "en" ? en : zh }

/// 切换语言：记下来，重新打开一个新的 AgentDock，再退出当前这个
func switchLanguage(to lang: String) {
    guard lang != appLang else { return }
    UserDefaults.standard.set(lang, forKey: appLanguageKey)
    UserDefaults.standard.synchronize()
    let cfg = NSWorkspace.OpenConfiguration()
    cfg.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { _, _ in
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}

/// 数据里存的状态、结论取值（中文枚举）→ 显示文字
func stateLabel(_ s: String) -> String {
    guard isEnglish else { return s }
    return ["进行中": "In progress", "卡住": "Blocked", "等你定": "Your call", "已解决": "Done", "搁置": "Paused",
            "有效": "Works", "无效": "Doesn't work", "待验证": "Unverified",
            "新大类": "New workstream", "改目标": "New goal", "改大类": "Revise workstream"][s] ?? s
}
