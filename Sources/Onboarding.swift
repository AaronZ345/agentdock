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

    private let titles = ["欢迎使用 AgentDock", "找到的应用", "开启辅助功能权限", "平时怎么用", "项目看板（可选）"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(titles.indices, id: \.self) { i in
                    Capsule().fill(i <= step ? Color.accentColor : Color.primary.opacity(0.12)).frame(height: 4)
                }
            }
            .padding(.horizontal, 28).padding(.top, 22)
            VStack(alignment: .leading, spacing: 16) {
                Text(titles[step]).font(.title2.weight(.semibold))
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
                Button("跳过") { done() }.buttonStyle(.borderless).foregroundStyle(.secondary)
                Spacer()
                if step > 0 { Button("上一步") { step -= 1 } }
                if step < titles.count - 1 {
                    Button("下一步") { step += 1 }.keyboardShortcut(.defaultAction)
                } else {
                    Button("开始使用") { done() }.keyboardShortcut(.defaultAction)
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
                para("在一个窗口里查看和回复 Claude 桌面版、Codex、Antigravity 的全部会话。")
            }
            bullet("tray.full", "所有会话放在一起", "按时间、目录或项目分组；未读、在跑、等你批准的一眼看到。")
            bullet("paperplane", "直接在这里回复", "发消息、回答提问、批准操作、切模型和权限，原应用不用切到前台。")
            bullet("square.grid.2x2", "项目看板", "多个 agent 一起推进项目时，自动汇总每个项目的目标、进度和验证过的结论，防止失焦。")
            bullet("lock.shield", "不改你的应用", "会话记录从本机直接读取；操作通过系统辅助功能和应用自带的本地接口完成，不改各应用的设置。")
        }
    }

    var apps: some View {
        VStack(alignment: .leading, spacing: 12) {
            para("AgentDock 不需要账号，直接读取本机这些应用的会话。没装的应用不影响其他应用使用。")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.agents) { a in
                    AgentCheck(a: a)
                    if a.id != model.agents.last?.id { Divider().padding(.leading, 48) }
                }
                if model.agents.isEmpty {
                    Text("正在查找…").foregroundStyle(.secondary).padding(14)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.035)))
            if !model.agents.contains(where: \.installed) {
                para("一个都没找到：请先安装并登录 Claude 桌面版、Codex 或 Antigravity 中的至少一个，用它们聊过之后会话就会出现在这里。")
            } else {
                para("应用不开着也能看会话；在 AgentDock 里发消息时，会在后台把对应应用打开。")
            }
        }
    }

    var permission: some View {
        VStack(alignment: .leading, spacing: 14) {
            para("看会话不需要任何权限。要在 AgentDock 里发消息、回答提问、批准操作、切模型，需要给它“辅助功能”权限：它会在后台替你操作原应用的界面。")
            HStack(spacing: 12) {
                Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 26)).foregroundStyle(trusted ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trusted ? "已开启" : "还没开启").font(.headline)
                    Text(trusted ? "可以在 AgentDock 里直接回复了。" : "点右边的按钮，在系统设置里找到 AgentDock 并打开开关。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if !trusted {
                    Button("打开系统设置") {
                        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill((trusted ? Color.green : Color.orange).opacity(0.08)))
            para("系统设置 → 隐私与安全性 → 辅助功能，打开 AgentDock 的开关。列表里没有的话点“＋”，从“应用程序”里选 AgentDock。打开后这里会自动变成“已开启”，不用重启。")
            para("以后更新 AgentDock 后如果发不出消息，回到这里把开关关掉再打开一次。")
        }
    }

    var usage: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet("sidebar.left", "左栏", "顶部按应用筛选、切换按时间 / 目录 / 项目分组；搜索框同时搜标题和正文。右键会话可以改名、分叉、置顶、归档、删除、归到项目。")
            bullet("text.bubble", "右边看对话", "点一条会话看完整对话、工具调用、后台任务和计划清单；对话随原应用实时更新。")
            bullet("keyboard", "底部输入框", "回车发送，可以加附件；会话正在跑时发的消息会排队，等它停下自动发出。输入框旁边能切模型和权限。")
            bullet("checkmark.bubble", "提问和批准", "原应用里的选择题、批准请求会显示成卡片，在这里点选就行。")
            bullet("plus", "新建会话", "左栏顶部的 ＋，选应用和目录，写第一条消息。")
            bullet("xmark.circle", "关窗口不退出", "点红点只是收起窗口，AgentDock 在后台继续同步；点程序坞图标打开，⌘Q 真正退出。")
        }
    }

    var board: some View {
        VStack(alignment: .leading, spacing: 12) {
            para("左栏顶部的方格按钮打开项目看板。它会把会话按项目归类，每轮回复结束后自动汇总每个项目的总目标、各大类进度、等你定的事和验证过的有效 / 无效做法。")
            bullet("cpu", "需要一个汇总 agent", "用本机的 Claude Code 命令行、Codex 或 Antigravity（Gemini）来汇总，在看板顶部选择。花的是对应账号的额度，每次十几秒到一两分钟。都没装时看板不会自动更新。")
            bullet("power", "默认不自动汇总", "打开看板后勾选顶部的“每轮回复结束后自动更新”才会开始；也可以点“从最近 7 天的会话建看板”先汇总一遍。")
            bullet("hand.raised", "目标和大类由你定", "模型起草后，总目标和大类只有你能改；它只更新进度和结论，想改目标时会作为建议等你采纳。")
            bullet("arrow.triangle.branch", "让会话读到看板（默认关）", "打开看板底部的“会话自动读到看板”，Claude Code 和 Codex 的会话会在看板有更新时自动收到精简版。这一项要改它们的钩子配置，打开前会说明改哪些文件。")
            HStack {
                Spacer()
                Button("现在就打开看板") { done(); model.board = "" }
            }
        }
    }
}
