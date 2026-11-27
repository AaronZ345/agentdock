import Cocoa

// 界面语言：中文（默认）或英文。启动时读一次，切换后重启应用生效。
// 用法：tr("中文", "English")。只用于 Convoy 自己的界面文案；
// 匹配原应用界面的文字（Labels.swift）、写进数据里的内部取值（大类状态“进行中”、结论“有效”等）不要翻译

let appLanguageKey = "appLanguage"

/// 当前语言。tr() 会在后台线程里调用，读的是一个布尔值（读写都是一步完成，不会读到一半）
private var _english: Bool = {
    // 测试和截图用：--lang en / --lang zh 临时指定，不改保存的设置
    let a = CommandLine.arguments
    if let i = a.firstIndex(of: "--lang"), a.count > i + 1, ["zh", "en"].contains(a[i + 1]) { return a[i + 1] == "en" }
    return UserDefaults.standard.string(forKey: appLanguageKey) == "en"
}()

/// "zh" 或 "en"
var appLang: String { _english ? "en" : "zh" }
var isEnglish: Bool { _english }

@inline(__always)
func tr(_ zh: String, _ en: String) -> String { _english ? en : zh }

/// 界面订阅它：语言一变，整个窗口按新语言重画
final class LangStore: ObservableObject {
    static let shared = LangStore()
    @Published private(set) var code = appLang
    fileprivate func set(_ c: String) { code = c }
}

extension Notification.Name { static let languageChanged = Notification.Name("agentdock.languageChanged") }

/// 切换语言：存下来、立即生效（不用重启）。窗口整个重画，聊天页重新加载，会话列表重扫一遍
func switchLanguage(to lang: String) {
    guard lang != appLang, ["zh", "en"].contains(lang) else { return }
    UserDefaults.standard.set(lang, forKey: appLanguageKey)
    _english = lang == "en"
    LangStore.shared.set(lang)
    NotificationCenter.default.post(name: .languageChanged, object: nil)
}

/// 数据里存的状态、结论取值（中文枚举）→ 显示文字
func stateLabel(_ s: String) -> String {
    guard isEnglish else { return s }
    return ["进行中": "In progress", "卡住": "Blocked", "等你定": "Your call", "已解决": "Done", "搁置": "Paused",
            "有效": "Works", "无效": "Doesn't work", "待验证": "Unverified",
            "新大类": "New workstream", "改目标": "New goal", "改大类": "Revise workstream"][s] ?? s
}
