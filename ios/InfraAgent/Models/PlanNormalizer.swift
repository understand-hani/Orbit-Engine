import Foundation

struct PlanNormalizer {
    static func normalizedContext(_ context: UserContext) -> (context: UserContext, changed: Bool) {
        var updated = context
        let normalizedPlan = normalizedFullCyclePlan(
            context.plan.fullCyclePlan,
            direction: context.profile.goal.isEmpty ? context.plan.longTermGoal : context.profile.goal
        )
        let changed = normalizedPlan != context.plan.fullCyclePlan
        if changed {
            updated.plan.fullCyclePlan = normalizedPlan
            updated.plan.updatedAt = Date()
        }
        return (updated, changed)
    }

    static func normalizedFullCyclePlan(_ items: [String], direction: String) -> [String] {
        let cleaned = items
            .map(stripPhasePrefix)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return [] }

        let groups = grouped(cleaned, maxGroups: 4)
        return groups.enumerated().map { offset, group in
            let merged = merge(group, direction: direction, phaseIndex: offset + 1)
            return "第 \(offset + 1) 阶段：\(merged)"
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
}
