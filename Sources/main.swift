import SwiftUI

// 诊断模式：Convoy --dump-ax <应用路径> <输出文件>，导出那个应用的界面树后退出
let args = CommandLine.arguments
if demoMode { headless = true }
// 钩子：Claude Code / Codex 在你发消息、会话开始时调用，把这条会话所属项目的看板附进去
if args.contains("--board-hook") { boardHook(); exit(0) }
if let i = args.firstIndex(of: "--dump-ax"), args.count > i + 2 {
    dumpAX(appPath: args[i + 1], out: args[i + 2])
    exit(0)
}

// 测试模式：Convoy --test-ask <会话 id> <回答 JSON：[{"labels":[...],"other":""}]>，在原应用里回答那组问题，结果写进 send-debug.log
if let i = args.firstIndex(of: "--test-ask"), args.count > i + 2 {
    let s = scanSessions().first { $0.id == args[i + 1] }!
    let arr = (try? JSONSerialization.jsonObject(with: Data(args[i + 2].utf8))) as? [[String: Any]] ?? []
    let answers = arr.map { AskAnswer(labels: $0["labels"] as? [String] ?? [], other: $0["other"] as? String ?? "") }
    Task { @MainActor in
        guard let ask = readDetail(s).ask else { log("test-ask: 没有待回答的问题"); exit(1) }
        do { try await answerAsk(s, ask, answers); log("test-ask OK") }
        catch let e as SendError { log("test-ask FAIL \(e.message)") }
        catch { log("test-ask FAIL \(error)") }
        exit(0)
    }
    RunLoop.main.run()
}

// 测试模式：Convoy --test-send <会话 id> <文字>，完整走一遍模拟发送但不回车，结果写进 send-debug.log
if let i = args.firstIndex(of: "--test-send"), args.count > i + 2 {
    let s = scanSessions().first { $0.id == args[i + 1] }!
    Task { @MainActor in
        do {
            try await sendViaUI(s, args[i + 2], dryRun: true)
            log("test-send OK \(s.id)")
        } catch let e as SendError {
            log("test-send FAIL \(s.id): \(e.message)")
        }
        exit(0)
    }
    NSApplication.shared.run()
}

// 演练：--test-chip <会话 id> <model|perm>，打开下拉读出选项后原样关掉；--test-usage 读用量
if let i = args.firstIndex(of: "--test-chip"), args.count > i + 2 {
    let s = scanSessions().first { $0.id == args[i + 1] }!
    Task { @MainActor in
        do {
            let m = try await openChip(s, Chip(rawValue: args[i + 2])!)
            log("test-chip \(s.title): current=\(m.current) items=\(m.labels)")
            await closeChip(m)
            await sleep(0.4)
            log("test-chip closed, menu items left=\(axNodes(m.ax).filter { $0.role == "AXMenuItem" && $0.frame.height > 0 }.count) current=\(m.current)")
        } catch let e as SendError { log("test-chip FAIL \(e.message)") }
        exit(0)
    }
    NSApplication.shared.run()
}
if args.contains("--test-usage") {
    Task { @MainActor in
        for a in await readUsage() { log("usage \(a.app): \(a.items.map { "\($0.label) \($0.used.map { Int(($0 * 100).rounded()) } ?? -1)% \($0.note)" })") }
        exit(0)
    }
    NSApplication.shared.run()
}

// 同步演练：--test-sync <会话 id> <秒数>，在后台开详情页盯住这条会话，定时记下页面上最后一条
if let i = args.firstIndex(of: "--test-sync"), args.count > i + 2 {
    headless = true
    let model = Model()
    let sid = args[i + 1], secs = Double(args[i + 2]) ?? 30
    // 等第一遍扫描出来、列表里有这条会话再选中
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
        if model.sessions.contains(where: { $0.id == sid }) { model.selectedId = sid; t.invalidate() }
    }
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
        model.chat.web.evaluateJavaScript("JSON.stringify([S.items.length, (S.items[S.items.length-1]||{}).kind, ((S.items[S.items.length-1]||{}).text||(S.items[S.items.length-1]||{}).verb||'').slice(0,50), (S.items[S.items.length-1]||{}).ts])") { r, e in
            let file = model.selected?.transcript?.path ?? "-"
            let m = (try? FileManager.default.attributesOfItem(atPath: file)[.modificationDate] as? Date).map { Int(Date().timeIntervalSince($0)) } ?? -1
            log("sync page=\(r as? String ?? "\(String(describing: e))") file=\((file as NSString).lastPathComponent) fileAge=\(m)s running=\(model.selected?.running ?? false)")
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + secs) { exit(0) }
    NSApplication.shared.run()
}

// 演练：--test-draft-chip <codex|claude> <目录> <回到的会话 id>：打开新会话页、读模型下拉、关掉，再切回原会话
if let i = args.firstIndex(of: "--test-draft-chip"), args.count > i + 3 {
    Task { @MainActor in
        let kind = Kind(rawValue: args[i + 1])!
        let path = kind == .codex ? codexAppPath : claudeApps[0].path
        do {
            let ui = try await openNewSessionUI(kind: kind, appPath: path, folder: args[i + 2])
            log("draft: new session page ready, composer empty=\(composerEmpty(ui.composer))")

            for chip in [Chip.model, .perm] {
                let m = try await openChipOn(ui.app, ui.ax, ui.composer, chip, kind)
                log("draft chip \(chip): current=\(m.before) items=\(m.labels.prefix(6))")
                await closeChip(m)
                await sleep(0.4)
            }
        } catch let e as SendError { log("draft FAIL \(e.message)") }
        if let s = scanSessions().first(where: { $0.id == args[i + 3] }) {
            let ax = AXUIElementCreateApplication(runningApp(path)!.processIdentifier)
            log("draft: back to original = \(await navigateQuietly(ax, s) != nil)")
        }
        exit(0)
    }
    NSApplication.shared.run()
}

// 演练：--test-unread，读一次 Claude 侧栏的未读蓝点，和最终判出来的未读一起写进日志（含耗时）
if args.contains("--test-unread") {
    for _ in 0..<2 {
        let t0 = Date()
        let m = claudeSidebarUnread(claudeApps[0].path)
        log("test-unread sidebar \(Int(Date().timeIntervalSince(t0) * 1000))ms rows=\(m?.count ?? -1) unread=\(m?.filter { $0.value }.map(\.key) ?? [])")
    }
    let t0 = Date()
    let all = scanSessions()
    log("test-unread scan \(Int(Date().timeIntervalSince(t0) * 1000))ms native unread=\(all.filter(\.nativeUnread).map { "\($0.app):\($0.title)" })")
    exit(0)
}

// 演练：--test-ax-observe <应用路径> <秒数>，监听这个应用发出的界面事件，逐条写进日志
if let i = args.firstIndex(of: "--test-ax-observe"), args.count > i + 2 {
    let app = runningApp(args[i + 1])!
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    enableWebAX(ax)
    var obs: AXObserver?
    AXObserverCreate(app.processIdentifier, { _, el, note, _ in
        let role: String = axGet(el, kAXRoleAttribute) ?? "?"
        let t: String = axGet(el, kAXTitleAttribute) ?? ""
        let v = (axGet(el, kAXValueAttribute) as String?) ?? ""
        let d: String = axGet(el, kAXDescriptionAttribute) ?? ""
        log("axnote \(note) \(role) t=\(t.prefix(50)) v=\(v.prefix(30)) d=\(d.prefix(30))")
    }, &obs)
    for n in ["AXTitleChanged", "AXValueChanged", "AXUIElementDestroyed", "AXCreated", "AXLayoutChanged", "AXLiveRegionChanged",
              "AXLiveRegionCreated", "AXSelectedChildrenChanged", "AXRowCountChanged", "AXLoadComplete", "AXElementBusyChanged",
              "AXExpandedChanged", "AXInvalidStatusChanged", "AXSelectedRowsChanged", "AXMenuOpened", "AXAnnouncementRequested", "AXDescriptionChanged"] {
        let r = AXObserverAddNotification(obs!, ax, n as CFString, nil)
        log("axnote add \(n) = \(r.rawValue)")
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs!), .defaultMode)
    DispatchQueue.main.asyncAfter(deadline: .now() + (Double(args[i + 2]) ?? 20)) { exit(0) }
    RunLoop.main.run()
}

// 演练：--test-board [会话 id…]，不带 id 时列出最近的会话；带 id 时把这些会话汇总进看板，结果写进日志
if let i = args.firstIndex(of: "--test-board") {
    let all = scanSessions()
    let ids = Array(args[(i + 1)...])
    if ids.isEmpty {
        for s in all.sorted(by: { $0.updated > $1.updated }).prefix(40) { log("test-board session \(s.id) | \(s.app) | \(s.title) | \(s.updated)") }
        exit(0)
    }
    let store = BoardStore()
    store.lookup = { id in all.first { $0.id == id } }
    store.allSessions = { all }
    Task { @MainActor in
        if ids == ["ctx"] { store.writeContextFiles(); log("test-board ctx written"); exit(0) }
        if ids.first == "refresh-demo" {
            // 临时项目：你写的目标 + 一个你建的大类，再记一处修改，按修改刷新
            let p = store.newProject("测试删除")
            store.edit(p.id, note: "把项目总目标改成：验证看板按修改刷新") { $0.goal = "验证看板按修改刷新"; $0.goalByUser = true }
            store.edit(p.id, note: "新建大类「刷新链路」") { $0.tracks.append(Track(title: "刷新链路", manual: true)) }
            store.refresh(p.id)
            if ids.count > 1, let q = store.projects.first(where: { $0.name == ids[1] }) { store.refresh(q.id) }
            await store.runForTest([])
            for q in store.projects where q.name == "测试删除" || (ids.count > 1 && q.name == ids[1]) {
                log("test-board refreshed \(q.name): goal=\(q.goal) byUser=\(q.goalByUser) edits=\(q.edits.count) tracks=\(q.tracks.map { "\($0.title)[\($0.state)\($0.manual ? ",你定的" : "")] \($0.now.prefix(40))" })")
            }
            exit(0)
        }
        if ids == ["rebuild"] {
            let all = store.projects.flatMap(\.sessions)
            for p in store.projects { store.rebuild(p) }
            await store.runForTest(all)
        } else {
            await store.runForTest(ids)
        }
        for p in store.projects { log("test-board project:\n" + store.markdown(p)) }
        if let e = store.lastError { log("test-board error \(e)") }
        exit(0)
    }
    NSApplication.shared.run()
}

// 演练：--test-board-render <输出目录>，把看板总览和每个项目的看板画成图片（不开窗口）
if let i = args.firstIndex(of: "--test-board-render"), args.count > i + 1 {
    headless = true
    let model = Model()
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
        guard !model.sessions.isEmpty else { return }
        t.invalidate()
        Task { @MainActor in
            @MainActor func png(_ v: some View, _ name: String) {
                let r = ImageRenderer(content: v.frame(minWidth: 620, idealWidth: name.hasPrefix("guide") ? 620 : 980, maxWidth: name.hasPrefix("guide") ? 620 : 980).fixedSize(horizontal: true, vertical: false).background(Color.white).environment(\.colorScheme, .light))
                r.scale = 1
                if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[i + 1] + "/" + name + ".png"))
                }
            }
            for i in 0..<5 { png(OnboardingView(model: model, done: {}, step: i), "guide\(i)") }
            png(BoardOverview(model: model, store: model.boards).content, "overview")
            // 排版耗时（不含出图）：用真实窗口里的宿主视图排一遍
            @MainActor func layoutMs(_ v: some View) -> Int {
                let t = Date()
                let h = NSHostingView(rootView: v.frame(width: 980))
                h.frame = NSRect(x: 0, y: 0, width: 980, height: 800)
                _ = h.fittingSize
                h.layoutSubtreeIfNeeded()
                return Int(Date().timeIntervalSince(t) * 1000)
            }
            for p in model.boards.projects {
                let e = layoutMs(ProjectBoard(model: model, store: model.boards, p: p, open: Set(p.tracks.map(\.id))).content)
                let c = layoutMs(ProjectBoard(model: model, store: model.boards, p: p).content)
                log("test-board-render layout \(p.name): expanded \(e)ms collapsed \(c)ms")
            }
            for (n, p) in model.boards.projects.enumerated() {
                let t0 = Date()
                png(ProjectBoard(model: model, store: model.boards, p: p, open: Set(p.tracks.map(\.id))).content, "project\(n)")
                let t1 = Date()
                png(ProjectBoard(model: model, store: model.boards, p: p).content, "project\(n)c")
                log("test-board-render \(p.name): expanded \(Int(t1.timeIntervalSince(t0) * 1000))ms collapsed \(Int(Date().timeIntervalSince(t1) * 1000))ms")
            }
            log("test-board-render done")
            exit(0)
        }
    }
    NSApplication.shared.run()
}

// 演练：--test-press <应用路径> <按钮名>…，在那个应用里依次按下这些按钮 / 菜单项（标签包含即可），每步间隔 1.5 秒，结果写进日志
if let i = args.firstIndex(of: "--test-press"), args.count > i + 2 {
    let app = runningApp(args[i + 1])!
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    for label in args[(i + 2)...] {
        if label.hasPrefix("type=") {
            let f = axNodes(ax).first { $0.role == "AXTextField" && $0.frame.width > 100 }
            if let f { AXUIElementSetAttributeValue(f.el, kAXValueAttribute as CFString, String(label.dropFirst(5)) as CFString) }
            log("test-press type: field=\(f != nil)")
            Thread.sleep(forTimeInterval: 0.8)
            continue
        }
        let hits = axNodes(ax).filter { ["AXButton", "AXMenuItem", "AXMenuButton", "AXPopUpButton", "AXCheckBox", "AXRadioButton"].contains($0.role) && ($0.label == label || (label.count > 1 && $0.label.contains(label))) }
        log("test-press \(label): \(hits.map { "\($0.role) \($0.label.prefix(40))" })")
        if let h = hits.first { log("test-press \(label) result=\(AXUIElementPerformAction(h.el, kAXPressAction as CFString).rawValue)") }
        Thread.sleep(forTimeInterval: 1.5)
    }
    exit(0)
}

// 自检：--test-check，跑一次自检把结果写进日志
if args.contains("--test-check") {
    Task { @MainActor in
        for c in await selfCheck(scanSessions()) { log("check \(c.app) \(c.version): " + c.items.map { "\($0.name)=\($0.ok ? "✓" : "✗")" }.joined(separator: " ")) }
        exit(0)
    }
    NSApplication.shared.run()
}

/// 点程序坞图标：窗口被关（藏起来）了就重新打开
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        if !headless { DispatchQueue.global(qos: .utility).async { migrateBoardHooks() } }
        if demoMode, let i = args.firstIndex(of: "--demo-shots"), args.count > i + 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                MainActor.assumeIsolated {
                    if let m = demoModelRef {
                        runDemoShots(m, out: args[i + 1])
                    }
                }
            }
        }
        // 窗口收起来后要留在后台继续同步：不让系统把“没有窗口的应用”自动或突然结束掉
        ProcessInfo.processInfo.disableAutomaticTermination("Convoy 在后台同步会话")
        ProcessInfo.processInfo.disableSuddenTermination()
        // 点一下就生效：窗口不在前台时，系统默认只拿第一下点击来激活窗口，按钮要点第二下。
        // 在事件分发之前先把窗口设成前台主窗口，这一下照常交给被点的按钮、会话行
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .leftMouseUp]) { e in
            if let w = e.window {
                let v = w.contentView?.hitTest(e.locationInWindow)
                let web = v.flatMap { hit in sequence(first: hit, next: { $0.superview }).first { $0 is ClickThroughWebView } } as? ClickThroughWebView
                if let web {
                    if e.type == .leftMouseDown {
                        // 聊天页没有键盘焦点时（刚点过左栏、刚切回来），按下那一刻先把焦点给它，
                        // 不让“接管焦点”和这次点击搅在一起（不然这一下常常只按下、不出点击）
                        if w.firstResponder !== web && !(w.firstResponder is NSView && (w.firstResponder as! NSView).isDescendant(of: web)) {
                            w.makeFirstResponder(web)
                        }
                    } else if e.type == .leftMouseUp {
                        // 兜底：页面收到了按下、却没等到点击时，替它补一下
                        web.evaluateJavaScript("window.AD && AD.nativeUp && AD.nativeUp()")
                    }
                }
            }
            if e.type == .leftMouseUp { return e }
            if let w = e.window, !w.isKeyWindow, w.canBecomeKey, w.isVisible {
                if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
                w.makeKey()
            }
            return e
        }
    }

    /// 最后一个窗口关了也不退出（SwiftUI 单窗口应用默认会退出）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { closeProxy.reopen() }
        return true
    }
}

struct ConvoyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = Model()
    @ObservedObject private var lang = LangStore.shared   // 菜单栏文字跟着语言变

    var body: some Scene {
        Window("Convoy", id: "main") {
            RootView(model: model).frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1240, height: 820)
        .commands {
            // 菜单栏：Convoy → 语言 / Language；帮助 → 使用引导
            CommandGroup(after: .appSettings) {
                Menu("语言 / Language") {
                    Button((lang.code == "zh" ? "✓ " : "") + "中文") { switchLanguage(to: "zh") }
                    Button((lang.code == "en" ? "✓ " : "") + "English") { switchLanguage(to: "en") }
                }
            }
            CommandGroup(replacing: .help) {
                Button(tr("使用引导", "Getting started guide")) { NotificationCenter.default.post(name: .showGuide, object: nil) }
            }
        }
    }
}

ConvoyApp.main()
