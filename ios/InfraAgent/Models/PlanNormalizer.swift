import Foundation

struct PlanNormalizer {
    static func normalizedContext(_ context: UserContext) -> (context: UserContext, changed: Bool) {
        var updated = context
        let normalizedPlan = normalizedFullCyclePlan(
            context.plan.fullCyclePlan,
            direction: context.profile.goal.isEmpty ? context.plan.longTermGoal : context.profile.goal,
            targetCycle: context.plan.targetCycle
        )
        let changed = normalizedPlan != context.plan.fullCyclePlan
        if changed {
            updated.plan.fullCyclePlan = normalizedPlan
            updated.plan.updatedAt = Date()
        }
        return (updated, changed)
    }

    static func normalizedFullCyclePlan(_ items: [String], direction: String, targetCycle: String = "") -> [String] {
        let formatted = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if formatted.count >= 3, formatted.count <= 4, formatted.allSatisfy(isStructuredPhase) {
            return formatted
        }

        let cleaned = items
            .map(phaseSourceText)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return [] }

        let groups = grouped(cleaned, maxGroups: 4)
        let timeRanges = phaseTimeRanges(targetCycle: targetCycle, count: groups.count)
        return groups.enumerated().map { offset, group in
            let merged = merge(group, direction: direction, phaseIndex: offset + 1)
            return formatPhase(
                index: offset + 1,
                timeRange: timeRanges[offset],
                body: merged,
                direction: direction
            )
        }
    }

    static func validationMessage(for items: [String]) -> String? {
        if items.count < 3 || items.count > 4 {
            return "全周期计划需要控制在 3-4 个阶段。当前阶段数：\(items.count)。"
        }
        if let vagueItem = items.first(where: isVaguePlanItem) {
            return "有阶段写得太空泛：\(vagueItem)。请把该阶段要做什么、产出什么写清楚。"
        }
        return nil
    }

    static func isVaguePlanItem(_ item: String) -> Bool {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 12 {
            return true
        }
        let lowered = trimmed.lowercased()
        let vagueTokens = ["等", "等等", "相关", "基础", "入门", "掌握", "了解", "学习", "vista", "dreamer", "world models"]
        let hasVagueToken = vagueTokens.contains { lowered.contains($0) }
        let hasDetailMarker = ["，", "。", "：", "、", "并", "完成", "整理", "形成", "输出", "复现", "对比"].contains { trimmed.contains($0) }
        return hasVagueToken && !hasDetailMarker
    }

    private static func grouped(_ items: [String], maxGroups: Int) -> [[String]] {
        guard items.count > maxGroups else {
            return items.map { [$0] }
        }

        let size = items.count / maxGroups
        let remainder = items.count % maxGroups
        var groups: [[String]] = []
        var cursor = 0

        for index in 0..<maxGroups {
            let groupSize = size + (index < remainder ? 1 : 0)
            groups.append(Array(items[cursor..<(cursor + groupSize)]))
            cursor += groupSize
        }
        return groups
    }

    private static func merge(_ group: [String], direction: String, phaseIndex: Int) -> String {
        if group.count == 1, let item = group.first {
            return isVaguePlanItem(item) ? expandVaguePlanItem(item, direction: direction, phaseIndex: phaseIndex) : item
        }

        let details = group
            .map { isVaguePlanItem($0) ? expandVaguePlanItem($0, direction: direction, phaseIndex: phaseIndex) : $0 }
            .joined(separator: "；")
        return "围绕「\(direction)」完成这一阶段的连续子任务：\(details)。这一阶段结束时形成一份可回看的阶段笔记或对比结论。"
    }

    private static func formatPhase(index: Int, timeRange: String, body: String, direction: String) -> String {
        let objective = body.trimmingCharacters(in: CharacterSet(charactersIn: "。 "))
        let lines: [String] = [
            "第 \(index) 阶段（\(timeRange)）",
            "目标：",
            "1. \(objective)。",
            "具体执行计划：",
            "1. 明确本阶段需要解决的 2-3 个关键问题和判断标准。",
            "2. 按关键问题筛选材料、完成 Deep Dive，并记录证据与结论。",
            "3. 阶段结束前复盘进度，整理未解决问题并确定下一阶段重点。",
            "产出：",
            "1. 一份「\(direction)」阶段研究笔记。",
            "2. 一份关键材料、方法或案例的对比清单。",
            "3. 一份下一阶段可直接执行的任务列表。"
        ]
        return lines.joined(separator: "\n")
    }

    private static func phaseSourceText(_ item: String) -> String {
        let text = stripPhasePrefix(item)
        guard let goalRange = text.range(of: "目标：") else { return text }
        var objective = String(text[goalRange.upperBound...])
        for marker in ["具体执行计划：", "子阶段：", "动作：", "产出："] {
            if let range = objective.range(of: marker) {
                objective = String(objective[..<range.lowerBound])
            }
        }
        return objective
            .components(separatedBy: .newlines)
            .map { line in
                var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if value.hasPrefix("- ") { value.removeFirst(2) }
                if value.count > 2 {
                    let prefix = value.prefix(2)
                    if prefix.first?.isNumber == true && (prefix.last == "." || prefix.last == "、") {
                        value.removeFirst(2)
                    }
                }
                return value.trimmingCharacters(in: CharacterSet(charactersIn: "。； "))
            }
            .filter { !$0.isEmpty }
            .joined(separator: "；")
    }

    private static func expandVaguePlanItem(_ item: String, direction: String, phaseIndex: Int) -> String {
        let topic = normalizedVagueTopic(item)
        switch phaseIndex {
        case 1:
            return "围绕「\(topic)」补齐 \(direction) 所需的基础概念、代表材料和检索关键词，并整理一份阶段地图。"
        case 2:
            return "围绕「\(topic)」完成关键方法或路线对比，记录它和 \(direction) 的关系、适用边界以及值得继续追的点。"
        case 3:
            return "围绕「\(topic)」完成一次复现、案例拆解或实验草稿，把结果写成可展示的阶段输出。"
        default:
            return "围绕「\(topic)」把前面阶段的判断落到一个明确产出上，并说明它如何服务 \(direction)。"
        }
    }

    private static func normalizedVagueTopic(_ item: String) -> String {
        var topic = item.trimmingCharacters(in: CharacterSet(charactersIn: "。；， "))
        let lowered = topic.lowercased()
        if lowered.contains("vista") {
            return "一条候选世界模型路线"
        }
        if lowered.contains("dreamer") {
            return "Dreamer 这类世界模型方法"
        }
        if lowered.contains("world models") {
            return "World Models 方向的核心方法"
        }
        if topic.hasSuffix("等") {
            topic.removeLast()
        }
        return topic
    }

    private static func stripPhasePrefix(_ item: String) -> String {
        let text = item.trimmingCharacters(in: .whitespacesAndNewlines)
        for index in 1...20 {
            let spaced = "第 \(index) 阶段："
            let compact = "第\(index)阶段："
            if text.hasPrefix(spaced) {
                return String(text.dropFirst(spaced.count))
            }
            if text.hasPrefix(compact) {
                return String(text.dropFirst(compact.count))
            }
        }
        return text
    }

    private static func isStructuredPhase(_ item: String) -> Bool {
        item.contains("目标：") &&
            item.contains("具体执行计划：") &&
            item.contains("产出：") &&
            item.contains("\n1. ") &&
            item.contains("（") &&
            item.contains("）")
    }

    private static func phaseTimeRanges(targetCycle: String, count: Int) -> [String] {
        if let totalMonths = parseTotalMonths(targetCycle) {
            return numberRanges(total: totalMonths, count: count, unit: "个月")
        }
        if let totalWeeks = parseTotalWeeks(targetCycle) {
            return numberRanges(total: totalWeeks, count: count, unit: "周")
        }
        return (1...count).map { "阶段 \($0)/\(count)" }
    }

    private static func parseTotalMonths(_ targetCycle: String) -> Int? {
        let text = targetCycle.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return nil
        }
        if text.contains("半年") {
            return 6
        }
        if text.contains("一年") || text.contains("1年") {
            return 12
        }
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits), value > 0 else {
            return nil
        }
        if text.contains("年") {
            return value * 12
        }
        if text.contains("月") || text.contains("个月") {
            return value
        }
        return nil
    }

    private static func parseTotalWeeks(_ targetCycle: String) -> Int? {
        let text = targetCycle.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = text.filter(\.isNumber)
        guard text.contains("周"), let value = Int(digits), value > 0 else {
            return nil
        }
        return value
    }

    private static func numberRanges(total: Int, count: Int, unit: String) -> [String] {
        var ranges: [String] = []
        var cursor = 1

        for index in 0..<count {
            let remainingGroups = count - index
            let remainingUnits = total - cursor + 1
            let span = max(remainingUnits / remainingGroups, 1)
            let end = min(cursor + span - 1, total)
            if cursor == end {
                ranges.append("第 \(cursor) \(unit)")
            } else {
                ranges.append("第 \(cursor)-\(end) \(unit)")
            }
            cursor = end + 1
        }
        return ranges
    }
}
