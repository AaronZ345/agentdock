import Foundation

// 正文搜索：在每条会话的全部提问和回复里找关键词。数据来自 Transcript.swift 的历史骨架（增量读取并缓存），
// 启动后在后台先把所有会话扫一遍，之后搜索基本是即时的。

struct SearchHit: Identifiable, Hashable {
    var id: String { sessionId + "|" + itemId }
    let sessionId: String
    let itemId: String
    let role: String        // user / assistant
    let before: String      // 命中词前面一小段
    let match: String
    let after: String
    let ts: String
}

private func line(_ s: Substring) -> String {
    s.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "  ", with: " ")
}

/// 在这些会话里搜 query，每条会话最多 3 处，总共最多 80 处，按会话的先后顺序
func searchSessions(_ sessions: [Session], _ query: String) -> [SearchHit] {
    let q = query.trimmingCharacters(in: .whitespaces)
    guard q.count >= 2 else { return [] }
    var out: [SearchHit] = []
    for s in sessions {
        guard let f = s.transcript else { continue }
        var n = 0
        for it in historyItems(s.kind, f).reversed() {   // 新的在前
            guard let r = it.text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            let lo = it.text.index(r.lowerBound, offsetBy: -24, limitedBy: it.text.startIndex) ?? it.text.startIndex
            let hi = it.text.index(r.upperBound, offsetBy: 60, limitedBy: it.text.endIndex) ?? it.text.endIndex
            out.append(SearchHit(sessionId: s.id, itemId: it.id, role: it.kind,
                                 before: (lo > it.text.startIndex ? "…" : "") + line(it.text[lo..<r.lowerBound]),
                                 match: String(it.text[r]), after: line(it.text[r.upperBound..<hi]) + (hi < it.text.endIndex ? "…" : ""),
                                 ts: it.ts))
            n += 1
            if n >= 3 || out.count >= 80 { break }
        }
        if out.count >= 80 { break }
    }
    return out
}

/// 预先把所有会话的历史骨架读一遍
func warmSearch(_ sessions: [Session]) {
    for s in sessions { if let f = s.transcript { _ = historyItems(s.kind, f) } }
}
