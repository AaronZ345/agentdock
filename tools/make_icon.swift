// 画 Convoy 图标：暖炭灰圆角底，三张错开叠放的对话卡片，分别是 Claude 橙、Codex 白、Antigravity 蓝紫，
// 底部一条“坞”托住它们。输出各尺寸 PNG 到 iconset 目录，再用 iconutil 合成 icns。
import AppKit

func rgb(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: a)
}

func draw(_ size: Int) -> Data {
    let s = CGFloat(size)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s / 1024, y: s / 1024)

    // 圆角底板（macOS 图标网格：内容 824，四边留 100）
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(platePath); ctx.setFillColor(rgb(0x262624)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(platePath); ctx.clip()
    let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x34332F), rgb(0x1E1D1B)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // 顶部一点暖光
    let glow = CGGradient(colorsSpace: cs, colors: [rgb(0xD97757, 0.22), rgb(0xD97757, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 860), startRadius: 0, endCenter: CGPoint(x: 330, y: 860), endRadius: 520, options: [])
    ctx.restoreGState()

    // 三张对话卡片，从后往前：Antigravity、Codex、Claude
    func card(_ r: CGRect, _ fill: (CGContext, CGRect) -> Void, lines: CGColor) {
        let p = CGPath(roundedRect: r, cornerWidth: 54, cornerHeight: 54, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.35))
        ctx.addPath(p); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState(); ctx.addPath(p); ctx.clip(); fill(ctx, r); ctx.restoreGState()
        // 卡片上的两行“文字”
        ctx.setFillColor(lines)
        for (i, w) in [0.62, 0.42].enumerated() {
            let lr = CGRect(x: r.minX + 52, y: r.maxY - 74 - CGFloat(i) * 46, width: (r.width - 104) * w, height: 22)
            ctx.addPath(CGPath(roundedRect: lr, cornerWidth: 11, cornerHeight: 11, transform: nil)); ctx.fillPath()
        }
    }
    card(CGRect(x: 300, y: 560, width: 470, height: 230), { c, r in
        let g = CGGradient(colorsSpace: cs, colors: [rgb(0x4285F4), rgb(0x9B72CB)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])
    }, lines: rgb(0xFFFFFF, 0.55))
    card(CGRect(x: 250, y: 430, width: 470, height: 230), { c, r in
        c.setFillColor(rgb(0xF2F0EA)); c.fill(r)
    }, lines: rgb(0x262624, 0.35))
    card(CGRect(x: 200, y: 300, width: 470, height: 230), { c, r in
        let g = CGGradient(colorsSpace: cs, colors: [rgb(0xE08A6B), rgb(0xC96442)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])
    }, lines: rgb(0xFFFFFF, 0.6))

    // 底部的“坞”
    let dock = CGRect(x: 180, y: 205, width: 664, height: 52)
    ctx.addPath(CGPath(roundedRect: dock, cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.setFillColor(rgb(0xFAF9F5, 0.88)); ctx.fillPath()
    // 坞上三个小灯：三个 agent
    for (i, c) in [0xD97757, 0xECECEC, 0x6F8DF0].enumerated() {
        ctx.setFillColor(rgb(UInt32(c)))
        ctx.fillEllipse(in: CGRect(x: 694 + CGFloat(i) * 44, y: 219, width: 24, height: 24))
    }

    let img = ctx.makeImage()!
    return NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (base, scales) in [(16, [1, 2]), (32, [1, 2]), (128, [1, 2]), (256, [1, 2]), (512, [1, 2])] {
    for k in scales {
        let name = k == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(base * k).write(to: out.appendingPathComponent(name))
    }
}
try! draw(1024).write(to: out.deletingLastPathComponent().appendingPathComponent("AppIcon-1024.png"))
