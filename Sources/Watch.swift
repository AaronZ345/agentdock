import Cocoa
import ApplicationServices

// 事件通知：文件一变、Claude 侧栏一变就刷新，不再定时轮询。
// - FileWatcher：系统的文件变动通知（FSEvents），盯住各应用写会话记录、状态库的目录
// - ClaudeSidebar：辅助功能通知（AXObserver），Claude 侧栏某一行的名字变了（多了或少了“未读回复”“运行中”）就收到一条

/// 盯住几个目录，里面有文件变了（且 accept 认这个路径）就在主线程回调一次；同一批变动合并成一次
final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let accept: (String) -> Bool
    private let onChange: () -> Void

    init(paths: [String], latency: Double = 0.3, accept: @escaping (String) -> Bool, onChange: @escaping () -> Void) {
        self.accept = accept
        self.onChange = onChange
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let cb: FSEventStreamCallback = { _, info, n, paths, _, _ in
            let me = Unmanaged<FileWatcher>.fromOpaque(info!).takeUnretainedValue()
            let list = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as! [String]
            if list.prefix(n).contains(where: me.accept) { me.onChange() }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty,
              let s = FSEventStreamCreate(nil, cb, &ctx, existing as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags)
        else { return }
        FSEventStreamSetDispatchQueue(s, .main)
        FSEventStreamStart(s)
        stream = s
    }

    deinit {
        if let s = stream { FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s) }
    }
}

/// Claude 侧栏的未读蓝点：启动时整读一遍侧栏，之后靠“行名变了”的通知逐行更新。
/// Claude 启动、退出时跟着挂上、摘掉监听
final class ClaudeSidebar {
    static let shared = ClaudeSidebar()
    /// 侧栏有变化（某行未读、在跑状态变了）时调用，在主线程
    var onChange: (() -> Void)?

    private let lock = NSLock()
    private var rows: [String: [String: Bool]] = [:]       // 应用路径 → 标题 → 是否未读
    private var observers: [String: (pid: pid_t, obs: AXObserver)] = [:]
    private var lastReread: [String: Date] = [:]
    private let queue = DispatchQueue(label: "agentdock.sidebar") // 整读侧栏在这里做，不卡主线程
    private var paths: [String] = []

    /// 只在主线程调用
    func start(_ appPaths: [String]) {
        paths = appPaths
        attachAll()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, let p = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleURL?.path,
                  self.paths.contains(p) else { return }
            // 刚启动时窗口和侧栏还没长出来，等一会儿再挂
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.attach(p) }
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, let p = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleURL?.path,
                  self.paths.contains(p) else { return }
            self.detach(p)
            self.onChange?()
        }
    }

    /// 挂上所有在跑的 Claude（已挂上的不动）。刚给了辅助功能授权时也靠它补挂
    func attachAll() { for p in paths { attach(p) } }

    /// 读不到（没挂上、侧栏收起来）时返回 nil，由会话表推算
    func snapshot(_ appPath: String) -> [String: Bool]? {
        lock.lock(); defer { lock.unlock() }
        return rows[appPath]
    }

    /// 侧栏里找不到某条会话（新开的、侧栏刚展开）：整读一遍，10 秒内最多一次
    func reread(_ appPath: String) {
        queue.async {
            if let t = self.lastReread[appPath], Date().timeIntervalSince(t) < 10 { return }
            self.readAll(appPath)
        }
    }

    private func readAll(_ appPath: String) {
        lastReread[appPath] = Date()
        let m = claudeSidebarUnread(appPath)
        lock.lock()
        let changed = rows[appPath] != m
        rows[appPath] = m
        lock.unlock()
        if changed { DispatchQueue.main.async { self.onChange?() } }
    }

    private func attach(_ appPath: String) {
        guard AXIsProcessTrusted(), let app = runningApp(appPath) else { return }
        let pid = app.processIdentifier
        if observers[appPath]?.pid == pid { return }
        detach(appPath)
        enableWebAX(AXUIElementCreateApplication(pid))
        var obs: AXObserver?
        let cb: AXObserverCallbackWithInfo = { _, el, note, _, refcon in
            let me = Unmanaged<ClaudeSidebar>.fromOpaque(refcon!).takeUnretainedValue()
            me.noted(el, note as String)
        }
        guard AXObserverCreateWithInfoCallback(pid, cb, &obs) == .success, let obs else { return }
        let ax = AXUIElementCreateApplication(pid)
        let me = Unmanaged.passUnretained(self).toOpaque()
        // 行名变化：未读回复、运行中这些状态词都写在行名里；窗口开关时整读一遍
        for n in [kAXTitleChangedNotification, kAXCreatedNotification, kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(obs, ax, n as CFString, me)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        observers[appPath] = (pid, obs)
        queue.async { self.readAll(appPath) }
        log("sidebar watch on: \(appPath)")
    }

    private func detach(_ appPath: String) {
        if let o = observers.removeValue(forKey: appPath) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o.obs), .defaultMode)
        }
        lock.lock(); rows[appPath] = nil; lock.unlock()
    }

    private func noted(_ el: AXUIElement, _ note: String) {
        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        guard let appPath = observers.first(where: { $0.value.pid == pid })?.key else { return }
        let role: String = axGet(el, kAXRoleAttribute) ?? ""
        if note != kAXTitleChangedNotification as String {
            // 窗口开了、关了：侧栏整个换了，重读
            if role == kAXWindowRole as String || role.isEmpty {
                queue.asyncAfter(deadline: .now() + 1) { self.readAll(appPath) }
            }
            return
        }
        guard role == kAXButtonRole as String, let row = claudeSidebarRow(el) else { return }
        lock.lock()
        let known = rows[appPath]?[row.title] != nil
        let changed = known && rows[appPath]?[row.title] != row.unread
        if changed { rows[appPath]?[row.title] = row.unread }
        lock.unlock()
        if changed { onChange?() } else if !known { reread(appPath) }
    }
}
