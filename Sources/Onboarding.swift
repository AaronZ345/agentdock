import SwiftUI

// 首次启动的引导：五步，讲清 AgentDock 是什么、找到了哪些应用、要开什么权限、平时怎么用、项目看板怎么开。
// 第一次打开时自动弹出，看完记下来不再自动弹；首页有“使用引导”可以再看

let onboardedKey = "onboarded.v1"

struct OnboardingView: View {
    @ObservedObject var model: Model
    let done: () -> Void
    @State var step = 0
    @State private var trusted = AXIsProcessTrusted()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()   // 只在引导开着时查权限有没有给

    private let titles = [tr("欢迎使用 AgentDock", "Welcome to AgentDock"), tr("找到的应用", "Apps found"), tr("开启辅助功能权限", "Turn on Accessibility"),
                          tr("平时怎么用", "Everyday use"), tr("项目看板（可选）", "Project board (optional)")]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(titles.indices, id: \.self) { i in
                    Capsule().fill(i <= step ? Color.accentColor : Color.primary.opacity(0.12)).frame(height: 4)
                }
            }
            .padding(.horizontal, 28).padding(.top, 22)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(titles[step]).font(.title2.weight(.semibold))
                    Spacer()
                    if step == 0 { LanguageSwitcher() }
                }
                Group {
                    switch step {
                    case 0: welcome
                    case 1: apps
                    case 2: permission
                    case 3: usage
                    default: board
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            HStack {
                Button(tr("跳过", "Skip")) { done() }.buttonStyle(.borderless).foregroundStyle(.secondary)
                Spacer()
                if step > 0 { Button(tr("上一步", "Back")) { step -= 1 } }
                if step < titles.count - 1 {
                    Button(tr("下一步", "Next")) { step += 1 }.keyboardShortcut(.defaultAction)
                } else {
                    Button(tr("开始使用", "Get started")) { done() }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 16)
        }
        .frame(width: 620, height: 560)
        .onReceive(timer) { _ in
            let t = AXIsProcessTrusted()
            if t != trusted { trusted = t; if t { model.refresh() } }
        }
    }

    private func para(_ s: String) -> some View {
        Text(s).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Color.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 各步

    var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                para(tr("在一个窗口里查看和回复 Claude 桌面版、Codex、Antigravity 的全部会话。", "See and reply to all your sessions from the Claude desktop app, Codex, and Antigravity in one window."))
            }
            bullet("tray.full", tr("所有会话放在一起", "All sessions in one place"),
                   tr("按时间、目录或项目分组；未读、在跑、等你批准的一眼看到。", "Group by time, folder, or project. Spot unread, running, and needs-approval sessions at a glance."))
            bullet("paperplane", tr("直接在这里回复", "Reply right here"),
                   tr("发消息、回答提问、批准操作、切模型和权限，原应用不用切到前台。", "Send messages, answer questions, approve actions, and switch models or permissions without bringing the original app to the front."))
            bullet("square.grid.2x2", tr("项目看板", "Project board"),
                   tr("多个 agent 一起推进项目时，自动汇总每个项目的目标、进度和验证过的结论，防止失焦。", "When several agents work on a project together, AgentDock summarizes each project’s goal, progress, and verified findings so nothing drifts."))
            bullet("lock.shield", tr("不改你的应用", "Leaves your apps alone"),
                   tr("会话记录从本机直接读取；操作通过系统辅助功能和应用自带的本地接口完成，不改各应用的设置。", "Sessions are read straight from this Mac. Actions go through macOS Accessibility and each app’s own local API, and no app settings are changed."))
        }
    }

    var apps: some View {
        VStack(alignment: .leading, spacing: 12) {
            para(tr("AgentDock 不需要账号，直接读取本机这些应用的会话。没装的应用不影响其他应用使用。", "AgentDock needs no account. It reads sessions from these apps directly on this Mac. Apps you don’t have installed won’t affect the others."))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.agents) { a in
                    AgentCheck(a: a)
                    if a.id != model.agents.last?.id { Divider().padding(.leading, 48) }
                }
                if model.agents.isEmpty {
                    Text(tr("正在查找…", "Looking…")).foregroundStyle(.secondary).padding(14)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.035)))
            if !model.agents.contains(where: \.installed) {
                para(tr("一个都没找到：请先安装并登录 Claude 桌面版、Codex 或 Antigravity 中的至少一个，用它们聊过之后会话就会出现在这里。", "None found. Install and sign in to at least one of the Claude desktop app, Codex, or Antigravity. Once you’ve chatted in it, your sessions will show up here."))
            } else {
                para(tr("应用不开着也能看会话；在 AgentDock 里发消息时，会在后台把对应应用打开。", "You can view sessions even when the apps aren’t running. When you send a message from AgentDock, the app is opened in the background."))
            }
        }
    }

    var permission: some View {
        VStack(alignment: .leading, spacing: 14) {
            para(tr("看会话不需要任何权限。要在 AgentDock 里发消息、回答提问、批准操作、切模型，需要给它“辅助功能”权限：它会在后台替你操作原应用的界面。", "Viewing sessions needs no permissions. To send messages, answer questions, approve actions, or switch models from AgentDock, give it Accessibility permission so it can operate the original app’s interface for you in the background."))
            HStack(spacing: 12) {
                Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 26)).foregroundStyle(trusted ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trusted ? tr("已开启", "On") : tr("还没开启", "Not on yet")).font(.headline)
                    Text(trusted ? tr("可以在 AgentDock 里直接回复了。", "You can now reply right from AgentDock.") : tr("点右边的按钮，在系统设置里找到 AgentDock 并打开开关。", "Click the button on the right, find AgentDock in System Settings, and turn it on."))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if !trusted {
                    Button(tr("打开系统设置", "Open System Settings")) {
                        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill((trusted ? Color.green : Color.orange).opacity(0.08)))
            para(tr("系统设置 → 隐私与安全性 → 辅助功能，打开 AgentDock 的开关。列表里没有的话点“＋”，从“应用程序”里选 AgentDock。打开后这里会自动变成“已开启”，不用重启。", "Go to System Settings → Privacy & Security → Accessibility and turn on AgentDock. If it’s not in the list, click “+” and choose AgentDock from Applications. This page switches to “On” automatically; no restart needed."))
            para(tr("以后更新 AgentDock 后如果发不出消息，回到这里把开关关掉再打开一次。", "If messages stop sending after an AgentDock update, come back here and turn the switch off and on again."))
        }
    }

    var usage: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet("sidebar.left", tr("左栏", "Sidebar"),
                   tr("顶部按应用筛选、切换按时间 / 目录 / 项目分组；搜索框同时搜标题和正文。右键会话可以改名、分叉、置顶、归档、删除、归到项目。", "Filter by app at the top and group by time, folder, or project. Search covers both titles and messages. Right-click a session to rename, fork, pin, archive, delete, or move it to a project."))
            bullet("text.bubble", tr("右边看对话", "Conversation on the right"),
                   tr("点一条会话看完整对话、工具调用、后台任务和计划清单；对话随原应用实时更新。", "Click a session to see the full conversation, tool calls, background tasks, and plan. It updates live along with the original app."))
            bullet("keyboard", tr("底部输入框", "Message box"),
                   tr("回车发送，可以加附件；会话正在跑时发的消息会排队，等它停下自动发出。输入框旁边能切模型和权限。", "Press Return to send; attachments are supported. Messages sent while a session is running are queued and go out automatically when it stops. Switch models and permissions next to the box."))
            bullet("checkmark.bubble", tr("提问和批准", "Questions and approvals"),
                   tr("原应用里的选择题、批准请求会显示成卡片，在这里点选就行。", "Multiple-choice questions and approval requests from the original app show up as cards. Just click to respond."))
            bullet("plus", tr("新建会话", "New session"),
                   tr("左栏顶部的 ＋，选应用和目录，写第一条消息。", "Click ＋ at the top of the sidebar, pick an app and folder, and write the first message."))
            bullet("xmark.circle", tr("关窗口不退出", "Closing the window doesn’t quit"),
                   tr("点红点只是收起窗口，AgentDock 在后台继续同步；点程序坞图标打开，⌘Q 真正退出。", "The red button just hides the window, and AgentDock keeps syncing in the background. Click the Dock icon to reopen it; press ⌘Q to quit."))
        }
    }

    var board: some View {
        VStack(alignment: .leading, spacing: 12) {
            para(tr("左栏顶部的方格按钮打开项目看板。它会把会话按项目归类，每轮回复结束后自动汇总每个项目的总目标、各大类进度、等你定的事和验证过的有效 / 无效做法。", "The grid button at the top of the sidebar opens the project board. It groups sessions by project and, after each reply, summarizes each project’s overall goal, progress per workstream, what needs your decision, and verified approaches that work or don’t."))
            bullet("cpu", tr("需要一个汇总 agent", "Needs an agent summarizer"),
                   tr("用本机的 Claude Code 命令行、Codex 或 Antigravity（Gemini）来汇总，在看板顶部选择。花的是对应账号的额度，每次十几秒到一两分钟。都没装时看板不会自动更新。", "Summaries are made by the Claude Code CLI, Codex, or Antigravity (Gemini) on this Mac; choose one at the top of the board. It uses that account’s quota, about 10 seconds to 2 minutes each time. If none is installed, the board won’t update automatically."))
            bullet("power", tr("默认不自动汇总", "Auto-summary is off by default"),
                   tr("打开看板后勾选顶部的“每轮回复结束后自动更新”才会开始；也可以点“从最近 7 天的会话建看板”先汇总一遍。", "It starts only after you check “Auto-update after each reply” at the top of the board. You can also click “Build board from the last 7 days” to summarize once first."))
            bullet("hand.raised", tr("目标和大类由你定", "You own the goal and workstreams"),
                   tr("模型起草后，总目标和大类只有你能改；它只更新进度和结论，想改目标时会作为建议等你采纳。", "After the model drafts them, only you can change the overall goal and workstreams. It only updates progress and findings; if it wants to change the goal, it leaves a suggestion for you to accept."))
            bullet("arrow.triangle.branch", tr("让会话读到看板（默认关）", "Share the board with sessions (off by default)"),
                   tr("打开看板底部的“会话自动读到看板”，Claude Code 和 Codex 的会话会在看板有更新时自动收到精简版。这一项要改它们的钩子配置，打开前会说明改哪些文件。", "Turn on “Share board with sessions” at the bottom of the board, and Claude Code and Codex sessions get a condensed version whenever the board updates. This changes their hook config; AgentDock tells you which files before turning it on."))
            HStack {
                Spacer()
                Button(tr("现在就打开看板", "Open the board now")) { done(); model.board = "" }
            }
        }
    }
}
