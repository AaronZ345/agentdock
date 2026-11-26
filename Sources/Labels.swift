import Foundation

// 后台操作要认的原应用按钮名，中英文都收。原应用换成英文界面、或改版换了说法时，只需要改这里。

enum L {
    static let send = ["发送", "Send", "Send message", "Submit"]
    static let stop = ["停止", "Stop", "Stop generating", "Interrupt"]

    // 输入框下方的下拉框
    static let modelPrefix = ["模型：", "Model: ", "Model:"]
    static let permPrefix = ["权限：", "Permissions: ", "Permission: ", "Mode: "]
    static let claudePermNames = ["自动", "手动", "接受编辑", "计划", "跳过权限确认",
                                  "Auto", "Ask", "Ask permissions", "Accept edits", "Plan", "Plan mode", "Bypass permissions"]
    static let codexPerm = ["更改权限", "Change permissions", "Permissions"]
    static let codexEffort = ["强度", "Effort", "Reasoning effort"]

    // Claude 侧栏一行的名字里，表示挂着未读蓝点的状态词
    static let claudeUnread = ["未读回复", "未讀回覆", "Unread reply", "Unread"]

    // 用量
    static let claudeUsagePrefix = ["用量：", "Usage: ", "Usage:"]
    static let codexUsage = ["用量", "Usage"]

    // 新建会话
    static let newChat = ["新聊天", "New chat", "New thread"]
    static func claudeNew(_ folder: String) -> [String] { ["在 \(folder) 中新建会话", "New session in \(folder)"] }
    static func codexNew(_ folder: String) -> [String] { ["在 \(folder) 中开始新聊天", "Start new chat in \(folder)", "New chat in \(folder)"] }

    // 会话菜单
    static func claudeMore(_ title: String) -> [String] { ["\(title) 的更多选项", "More options for \(title)", "\(title) options", "Options for \(title)"] }
    static let renameField = ["重命名", "聊天标题", "Rename", "Chat title", "Title"]
    static let save = ["保存", "Save"]
    static let deleteConfirm = ["删除", "永久删除", "确认删除", "Delete", "Delete permanently", "Confirm"]

    /// 会话操作的菜单路径：每一步是一组同义词，按到其中任意一个就算这一步完成
    static let menuPath: [Kind: [SessionAction: [[String]]]] = [
        .claude: [.rename: [["重命名", "Rename"]], .fork: [["分叉", "Fork"]], .pin: [["置顶", "取消置顶", "Pin", "Unpin"]],
                  .archive: [["归档", "Archive"]], .delete: [["删除", "Delete"]]],
        .codex: [.rename: [["重命名", "Rename"]], .fork: [["分叉", "Fork"], ["创建聊天分支", "Create branch", "Fork chat"]],
                 .pin: [["置顶", "取消置顶", "Pin", "Unpin"]], .archive: [["归档", "Archive"]],
                 .delete: [["永久删除", "Delete permanently", "Delete"]]],
        .antigravity: [.rename: [["Rename", "重命名"]], .fork: [["Split", "拆分"]], .pin: [["Pin", "Unpin", "置顶"]],
                       .archive: [["Archive", "归档"]], .delete: [["Delete", "删除"]]],
    ]

    // 批准请求里的按钮（Claude / Codex 的批准卡片）
    static let approve = ["允许", "批准", "允许一次", "始终允许", "本次允许", "Allow", "Allow once", "Always allow", "Approve", "Accept"]
    static let deny = ["拒绝", "不允许", "Deny", "Reject", "Decline", "Don't allow"]

    // Claude 的问题卡片（AskUserQuestion）
    static let askNext = ["显示下一个问题", "Show next question", "Next question"]
    static let askPrev = ["显示上一个问题", "Show previous question", "Previous question"]
    static let askOther = ["其他", "Other"]
    static let askSubmit = ["下一步", "提交", "完成", "Next", "Submit", "Done"]

    static func any(_ label: String, _ names: [String]) -> Bool { names.contains(label) }
    static func anyPrefix(_ label: String, _ names: [String]) -> Bool { names.contains { label.hasPrefix($0) } }
    /// 菜单项可能带快捷键或说明：“Pin ⌥⌘P”、“自动 由 Claude 处理权限决策”
    static func item(_ label: String, _ names: [String]) -> Bool { names.contains { label == $0 || label.hasPrefix($0 + " ") } }
    static func stripPrefix(_ label: String, _ ps: [String]) -> String {
        for p in ps where label.hasPrefix(p) { return String(label.dropFirst(p.count)) }
        return label
    }
}
