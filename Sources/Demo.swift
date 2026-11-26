import Cocoa
import WebKit

// 演示模式：AgentDock --demo-shots <输出目录>
// 用编出来的会话和项目把界面跑起来，截几张图给 README 用（不碰真实会话，也不写任何数据文件）。
// 主窗口截图：SwiftUI 部分用窗口自己画，聊天页（网页）用网页视图自己的截图，再拼起来

let demoMode = CommandLine.arguments.contains("--demo-shots")
var demoModelRef: Model?

private let demoDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("agentdock-demo")
private func ago(_ min: Double) -> Date { Date().addingTimeInterval(-min * 60) }
private func iso(_ min: Double) -> String { ISO8601DateFormatter().string(from: ago(min)) }

private func demoFile(_ id: String) -> URL {
    try? FileManager.default.createDirectory(at: demoDir, withIntermediateDirectories: true)
    let f = demoDir.appendingPathComponent(id + ".jsonl")
    if !FileManager.default.fileExists(atPath: f.path) { try? "".write(to: f, atomically: true, encoding: .utf8) }
    return f
}

private let claudeApp = claudeAppPath, codexApp = codexAppPath, agyApp = "/Applications/Antigravity.app"

func demoSessions() -> [Session] {
    func s(_ id: String, _ kind: Kind, _ app: String, _ path: String, _ title: String, _ project: String, _ min: Double,
           running: Bool = false, unread: Bool = false, waiting: Bool = false, model: String, perm: String) -> Session {
        var x = Session(id: id, kind: kind, rawId: id, transcript: demoFile(id), app: app, title: title, project: project,
                        running: running, updated: ago(min), link: nil, appPath: path)
        x.cwd = "/Users/demo/code/" + project
        x.model = model; x.perm = perm; x.waiting = waiting; x.nativeUnread = unread
        return x
    }
    return [
        s("demo-checkout", .claude, "Claude", claudeApp, "结账页改成单页流程", "shop-web", 1, running: true, model: "Opus 5.5 高", perm: "接受编辑"),
        s("demo-cache", .codex, "Codex", codexApp, "订单接口加缓存", "shop-api", 3, running: true, model: "GPT-6.2 高", perm: "自动"),
        s("demo-stock", .claude, "Claude", claudeApp, "修复购物车并发扣库存", "shop-api", 12, unread: true, model: "Opus 5.5 高", perm: "手动"),
        s("demo-push", .antigravity, "Antigravity", agyApp, "iOS 推送集成", "shop-ios", 25, waiting: true, model: "Gemini 4 Neon", perm: "Default"),
        s("demo-report", .codex, "Codex", codexApp, "周报数据看板", "analytics", 48, unread: true, model: "GPT-6.2 中", perm: "自动"),
        s("demo-a11y", .claude, "Claude", claudeApp, "登录页无障碍改进", "shop-web", 95, model: "Sonnet 5.5", perm: "接受编辑"),
        s("demo-vector", .antigravity, "Antigravity", agyApp, "评估向量数据库选型", "search", 180, model: "Gemini 4 Neon", perm: "Default"),
        s("demo-docs", .codex, "Codex", codexApp, "整理 API 文档", "shop-api", 60 * 26, model: "GPT-6.2 中", perm: "自动"),
        s("demo-ab", .claude, "Claude", claudeApp, "首页 A/B 实验分析", "analytics", 60 * 30, model: "Opus 5.5 高", perm: "手动"),
    ]
}

func demoDetail(_ s: Session) -> Detail {
    guard s.id == "demo-checkout" else {
        return Detail(items: [Item(id: s.id + "-u", kind: "user", text: s.title, ts: iso(30)),
                              Item(id: s.id + "-a", kind: "assistant", text: "好的，我先看一下相关代码。", ts: iso(29))],
                      tasks: [], suggestion: nil, plan: [])
    }
    var items: [Item] = [
        Item(id: "u1", kind: "user", text: "结账现在要走 3 个页面，流失很多。改成单页：地址、配送、支付放在一页，地址填完自动算运费。", ts: iso(42)),
        Item(id: "t1", kind: "thinking", text: "先找到现有的三个结账页面和它们之间传的数据，再决定合并后的组件结构。", ts: iso(41)),
    ]
    func tool(_ id: String, _ name: String, _ verb: String, _ target: String, _ out: String, _ min: Double, cat: String = "cmd") -> Item {
        var t = Item(id: id, kind: "tool", name: name, verb: verb, summary: target, input: target, output: out, done: true, ts: iso(min))
        t.cat = cat
        return t
    }
    items += [
        tool("c1", "Grep", "搜索", "checkout", "src/pages/checkout/Address.tsx\nsrc/pages/checkout/Shipping.tsx\nsrc/pages/checkout/Payment.tsx", 41, cat: "search"),
        tool("c2", "Read", "读取", "Shipping.tsx", "（212 行）", 40, cat: "read"),
        Item(id: "n1", kind: "note", text: "三个页面之间靠 URL 参数传地址 id，运费在第二页才请求。合并后改成一个表单状态，地址变化时防抖请求运费。", ts: iso(39)),
        tool("c3", "Edit", "编辑文件", "src/pages/checkout/Checkout.tsx", "", 30, cat: "edit"),
        tool("c4", "Edit", "编辑文件", "src/api/shipping.ts", "", 26, cat: "edit"),
        tool("c5", "Bash", "运行命令", "npm test -- checkout", "PASS  checkout/Checkout.test.tsx (14 tests)\nTests: 14 passed, 14 total", 20),
    ]
    var end = Item(id: "e1", kind: "turnend", text: "x", ts: iso(19), took: 23 * 60 * 1000)
    end.files = [FileStat(path: "src/pages/checkout/Checkout.tsx", kind: "add", add: 186, del: 0),
                 FileStat(path: "src/api/shipping.ts", kind: "edit", add: 24, del: 9),
                 FileStat(path: "src/pages/checkout/Shipping.tsx", kind: "delete", add: 0, del: 212)]
    items += [
        Item(id: "a1", kind: "assistant", text: """
        结账已改成单页，测试 14 个全部通过。

        - **一页填完**：地址、配送方式、支付方式在同一页，从上到下填。
        - **运费自动算**：地址填完 0.4 秒后自动请求运费，不用再点“下一步”。
        - **旧页面**：原来三个页面删掉了，旧链接会跳到新页面。

        还没做：手机上的布局只在模拟器里看过。
        """, ts: iso(19)),
        end,
        Item(id: "u2", kind: "user", text: "可以，再把优惠券输入也放进来，放在支付上面。", ts: iso(3)),
        tool("c6", "Read", "读取", "Coupon.tsx", "（88 行）", 2, cat: "read"),
    ]
    var d = Detail(items: items, tasks: [], suggestion: nil,
                   plan: [PlanItem(content: "找到优惠券组件和校验接口", status: "completed"),
                          PlanItem(content: "放进结账页、接上金额重算", status: "in_progress"),
                          PlanItem(content: "补测试", status: "pending")])
    d.model = s.model
    return d
}

func demoProjects() -> [Project] {
    func e(_ t: String, _ state: String = "", ev: String = "", date: String = "", s: String = "") -> BoardEntry {
        BoardEntry(text: t, date: date, session: s, state: state, evidence: ev)
    }
    var shop = Project(name: "电商网站改版")
    shop.goal = "下单转化率从 2.1% 提到 3% 以上，结账页首屏加载 1 秒内，上线前不出现超卖。"
    shop.status = "单页结账已完成、正在加优惠券；库存并发问题定位到扣减不是原子操作，修复方案等你定。"
    shop.decisions = [e("库存扣减用数据库行锁还是 Redis 原子扣减？行锁改动小，Redis 扛得住大促", s: "修复购物车并发扣库存")]
    shop.sessions = ["demo-checkout", "demo-stock", "demo-cache", "demo-a11y", "demo-docs"]
    shop.updated = ago(2)
    var t1 = Track(title: "结账转化率", goal: "下单转化率 ≥ 3%")
    t1.state = "进行中"; t1.now = "单页结账已上测试环境，正在加优惠券；转化率要上线一周后才有数。"; t1.updated = "11-26"
    t1.learned = [e("把多步表单合成一页，比优化单步文案更有效", "有效", ev: "灰度 10% 用户，结账完成率 41% → 52%"),
                  e("进结账前强制注册会显著流失", "无效", ev: "去掉强制注册后完成率 +6%"),
                  e("运费在填地址时就算出来，减少中途放弃", "待验证")]
    t1.next = [e("优惠券放到支付上方并重算金额"), e("手机端真机走一遍")]
    t1.log = [e("灰度结果：完成率 41% → 52%", date: "11-24"), e("单页结账合入测试环境", date: "11-26")]
    var t2 = Track(title: "库存不超卖", goal: "并发 500 下单压测零超卖")
    t2.state = "等你定"; t2.now = "已复现：两笔订单同时扣同一件库存会都成功。修复方案二选一，等你定。"; t2.updated = "11-26"
    t2.learned = [e("先查后扣在并发下必然超卖，扣减要做成一步原子操作", "有效", ev: "压测 200 并发复现 3 次超卖")]
    t2.next = [e("定方案后补压测脚本")]
    var t3 = Track(title: "首屏性能", goal: "结账页首屏 ≤ 1 秒（4G）")
    t3.state = "卡住"; t3.now = "首屏 1.6 秒，大头是支付 SDK 同步加载；SDK 方还没给异步版本。"; t3.updated = "11-25"
    t3.learned = [e("图片懒加载对结账页帮助很小", "无效", ev: "首屏 1.7 → 1.6 秒")]
    var t4 = Track(title: "无障碍与文档", goal: "登录和结账页通过读屏检查；API 文档覆盖全部接口")
    t4.state = "已解决"; t4.now = "登录页读屏检查全部通过，API 文档已补齐 32 个接口。"; t4.updated = "11-25"
    shop.tracks = [t1, t2, t3, t4]
    shop.suggestions = [BoardSuggestion(kind: "新大类", title: "订单接口缓存", goal: "订单查询 P95 ≤ 120 ms",
                                        reason: "「订单接口加缓存」会话里已经在做，现有大类装不下")]

    var data = Project(name: "数据周报")
    data.goal = "每周一 9 点前自动出周报看板，核心指标口径和财务一致。"
    data.status = "看板已能自动生成，GMV 口径和财务差 0.8%，在查退款时间点。"
    data.sessions = ["demo-report", "demo-ab"]; data.updated = ago(48)
    var d1 = Track(title: "指标口径对齐", goal: "GMV 与财务差 ≤ 0.1%"); d1.state = "进行中"; d1.now = "差 0.8%，怀疑退款按下单日还是退款日算。"
    var d2 = Track(title: "自动出报表", goal: "每周一 9 点前自动生成"); d2.state = "已解决"; d2.now = "定时任务已上线，连续两周按时生成。"
    data.tracks = [d1, d2]

    var app = Project(name: "iOS App")
    app.goal = "推送和深链上线，推送打开率 ≥ 8%。"
    app.status = "推送证书已配好，在等 Antigravity 那边批准修改 Info.plist。"
    app.sessions = ["demo-push"]; app.updated = ago(25)
    var a1 = Track(title: "推送集成", goal: "测试机收到推送并能跳转"); a1.state = "进行中"; a1.now = "证书配好，等批准修改 Info.plist 后联调。"
    app.tracks = [a1]
    return [shop, app, data]
}

// MARK: 截图

@MainActor
func runDemoShots(_ model: Model, out: String) {
    // 用系统截图截这个窗口（要“屏幕录制”权限；SwiftUI 的内容应用自己画不出来）
    func capture(_ name: String, sheet: Bool = false, done: @escaping () -> Void) {
        guard let main = NSApp.windows.first(where: { $0.isVisible && $0.frame.width > 700 }),
              let w = sheet ? main.attachedSheet : main else { done(); return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l", "\(w.windowNumber)", out + "/" + name + ".png"]
        try? p.run(); p.waitUntilExit()
        log("demo shot \(name) exit=\(p.terminationStatus)")
        done()
    }
    guard CGPreflightScreenCaptureAccess() else {
        _ = CGRequestScreenCaptureAccess()   // 让系统把 AgentDock 列进“屏幕录制”，你去打开开关
        log("demo: no screen capture permission")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exit(2) }
        return
    }
    if let w = NSApp.windows.first(where: { $0.frame.width > 600 }) {
        w.setContentSize(NSSize(width: 1320, height: 840))
        w.center()
    }
    model.mode = .project
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        model.selectedId = "demo-checkout"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            capture("main") {
                model.mode = .time
                model.board = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    capture("board") {
                        model.board = model.boards.projects.first?.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            capture("project") {
                                NotificationCenter.default.post(name: .showGuide, object: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { capture("guide", sheet: true) { exit(0) } }
                            }
                        }
                    }
                }
            }
        }
    }
}
