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
        let hasDetailMarker = ["，", "。", "；", "：", "、", "并", "完成", "整理", "形成", "输出", "复现", "对比"].contains { trimmed.contains($0) }
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
        let goals = phaseGoals(body)
        let details = phaseDetails(
            index: index,
            direction: direction,
            goals: goals,
            durationWeeks: phaseDurationWeeks(timeRange)
        )
        var lines: [String] = [
            "第 \(index) 阶段（\(timeRange)）",
            "目标："
        ]
        lines.append(contentsOf: goals.enumerated().map { "\($0.offset + 1). \($0.element)。" })
        lines.append("具体执行计划：")
        lines.append(contentsOf: details.steps.enumerated().map { "\($0.offset + 1). \($0.element)" })
        lines.append("产出：")
        lines.append(contentsOf: details.outputs.enumerated().map { "\($0.offset + 1). \($0.element)" })
        return lines.joined(separator: "\n")
    }

    private static func phaseGoals(_ body: String) -> [String] {
        let goals = goalCandidates(body)
        return goals.isEmpty ? ["完成本阶段目标"] : Array(goals.prefix(3))
    }

    private static func phaseDetails(index: Int, direction: String, goals: [String], durationWeeks: Int) -> (steps: [String], outputs: [String]) {
        let goalFocus = goalFocus(goals, direction: direction)
        let executionSteps = phaseExecutionSteps(index: index, goalFocus: goalFocus, durationWeeks: durationWeeks)
        switch index {
        case 1:
            return (
                executionSteps,
                ["一份「\(direction)」概念与问题地图。", "一份含材料类型、阅读优先级、对应问题和预计阅读时间的核心材料目录。", "一份需要在后续阶段验证的关键问题清单。"]
            )
        case 2:
            return (
                executionSteps,
                ["一份包含问题定义、证据、边界和取舍理由的路线对比矩阵。", "一组带来源的证据卡片与边界说明。", "一份可供下一阶段验证的阶段判断。"]
            )
        case 3:
            return (
                executionSteps,
                ["一个可复查的案例、实验或实践结果。", "一份包含阻塞点、偏差原因、改动记录和结果截图/链接的问题日志。", "一份基于验证结果的路线取舍结论。"]
            )
        default:
            return (
                executionSteps,
                ["一份完整的「\(direction)」阶段成果。", "一份结论、证据链与局限性说明。", "一份下一周期的优先级路线图。"]
            )
        }
    }

    private static func phaseExecutionSteps(index: Int, goalFocus: String, durationWeeks: Int) -> [String] {
        let templates = executionTemplates(index: index, goalFocus: goalFocus)
        return weekRanges(totalWeeks: max(durationWeeks, 1)).enumerated().map { offset, range in
            "\(weekLabel(start: range.start, end: range.end)) / Day 1-5：\(templates[min(offset, templates.count - 1)])"
        }
    }

    private static func executionTemplates(index: Int, goalFocus: String) -> [String] {
        switch index {
        case 1:
            return [
                "把「\(goalFocus)」拆成 3 个必须回答的问题，列出每个问题对应的关键词、反向关键词和判断标准。",
                "围绕「\(goalFocus)」筛出 5-8 份锚点材料，至少包含综述/经典论文、代表项目或官方文档、一个反例或争议来源。",
                "逐份材料记录核心概念、方法假设、输入输出、适用边界和与个人方向的关系，每份材料形成 5-8 行证据卡。",
                "把材料中的概念、方法、数据输入和评估指标整理成一张概念地图，标出高频术语和不确定术语。",
                "针对不确定术语补读 2-3 份材料，更新关键词表和证据卡，删除无法服务本阶段目标的材料。",
                "汇总阶段地图，标记下一阶段要比较的 2-3 条路线或方法，并写出每条路线值得比较的原因。"
            ]
        case 2:
            return [
                "从上一阶段清单中选择 2-3 条和「\(goalFocus)」最相关的路线，统一比较维度：问题定义、数据/输入、关键模块、训练或执行成本、失败场景。",
                "每天 Deep Dive 一条路线或一个代表案例，记录它解决了什么、没有解决什么、证据来自哪里。",
                "把路线放进同一张对比矩阵，补齐反例、边界条件和自己现有背景能切入的位置。",
                "为每条路线补一个失败案例或限制条件，避免只记录优点，并写清它对个人方向的影响。",
                "把对比矩阵压缩成 3-5 条阶段判断，给每条判断绑定证据来源和反例。",
                "写出路线取舍：哪条继续追、哪条暂缓、下一阶段应该用什么小验证来确认。"
            ]
        case 3:
            return [
                "把「\(goalFocus)」转成一个最小验证任务，写清输入、操作步骤、成功标准和失败时要记录的现象。",
                "完成第一个案例拆解、代码复现、实验草稿或数据整理任务，每天记录阻塞点、解决动作和中间结果。",
                "根据第一次结果做一次小改动或对照验证，明确变化来自材料理解、方法选择还是执行条件。",
                "补齐验证任务的证据链：输入样例、过程记录、结果截图或链接、失败日志和判断依据。",
                "围绕结果做一次复盘，列出保留、修正或放弃的路线，并说明原因。",
                "把验证结果整理成可展示产出草稿，写清下一步如果继续推进需要什么数据、材料或代码条件。"
            ]
        default:
            return [
                "按「\(goalFocus)」回收前序阶段的证据、判断和实践结果，标记缺口、重复结论和仍不可靠的判断。",
                "补齐 2-3 个影响最终结论的关键缺口，优先补证据来源、对照案例或失败边界。",
                "把材料目录、对比矩阵、验证结果整合成最终交付物初稿，明确每个结论对应的证据。",
                "请 Agent 或自己按证据链逐项检查最终交付物，标出缺失、过度推断和需要删减的内容。",
                "完成最终版，写清局限性、下一周期优先级和可以直接交给 Agent 继续推进的任务清单。",
                "把下一周期任务拆成候选材料、候选验证、候选输出三类，并选择第一周最应该启动的一项。"
            ]
        }
    }

    private static func weekRanges(totalWeeks: Int) -> [(start: Int, end: Int)] {
        var ranges: [(start: Int, end: Int)] = []
        var cursor = 1
        while cursor <= totalWeeks {
            let end = min(cursor + 1, totalWeeks)
            ranges.append((cursor, end))
            cursor = end + 1
        }
        return ranges
    }

    private static func weekLabel(start: Int, end: Int) -> String {
        start == end ? "Week \(start)" : "Week \(start)-\(end)"
    }

    private static func goalFocus(_ goals: [String], direction: String) -> String {
        for goal in goals {
            let cleaned = goal.trimmingCharacters(in: CharacterSet(charactersIn: "。；;，, ").union(.whitespacesAndNewlines))
            if !cleaned.isEmpty, cleaned != "完成本阶段目标" {
                return cleaned
            }
        }
        return direction
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
        return goalCandidates(objective).joined(separator: "；")
    }

    private static func goalCandidates(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n；;。")
        var candidates: [String] = []
        for line in text.components(separatedBy: separators) {
            let shouldSplitList = line.contains("连续子任务")
            let cleaned = cleanGoalCandidate(line)
            let parts = shouldSplitList ? cleaned.components(separatedBy: "、") : [cleaned]
            for part in parts {
                let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty, !candidates.contains(value) {
                    candidates.append(value)
                }
            }
        }
        return candidates
    }

    private static func cleanGoalCandidate(_ line: String) -> String {
        var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("- ") {
            value.removeFirst(2)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = value.range(of: #"^\d+[.、]\s*"#, options: .regularExpression) {
            value.removeSubrange(range)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = value.range(of: "目标：", options: .backwards) {
            value = String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = value.range(of: "连续子任务：", options: .backwards) {
            value = String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = value.range(of: #"^第\s*\d+\s*[-—~～至到]\s*\d+\s*(个月|月|周)\s*[:：]\s*"#, options: .regularExpression) {
            value.removeSubrange(range)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = value.range(of: #"^第\s*\d+\s*(个月|月|周)\s*[:：]\s*"#, options: .regularExpression) {
            value.removeSubrange(range)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for marker in ["具体执行计划：", "子阶段：", "动作：", "产出："] {
            if let range = value.range(of: marker) {
                value = String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        value = stripPhasePrefix(value)
        if let range = value.range(of: #"^第\s*\d+\s*阶段[（(][^）)]*[）)]\s*[:：;；,，]?\s*"#, options: .regularExpression) {
            value.removeSubrange(range)
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "。；;，, ").union(.whitespacesAndNewlines))
    }

    private static func expandVaguePlanItem(_ item: String, direction: String, phaseIndex: Int) -> String {
        let topic = normalizedVagueTopic(item)
        let lowered = topic.lowercased()
        if topic.contains("世界模型") || lowered.contains("world models") || lowered.contains("world model") {
            switch phaseIndex {
            case 1:
                return "梳理世界模型的状态表示、时序预测、训练信号、评估指标和自动驾驶场景输入输出。"
            case 2:
                return "对比 World Models、Dreamer、VISTA 等路线的问题定义、模型输入、关键模块、训练成本和失败场景。"
            case 3:
                return "完成一个最小世界模型验证任务，记录输入数据、运行步骤、结果现象和路线取舍。"
            default:
                return "整合世界模型路线判断、证据链、可复用材料目录和下一周期验证任务。"
            }
        }
        switch phaseIndex {
        case 1:
            return "明确「\(topic)」的核心概念、代表材料、检索关键词和判断标准。"
        case 2:
            return "对比「\(topic)」相关的关键方法、路线或案例，记录适用边界和继续追踪价值。"
        case 3:
            return "围绕「\(topic)」完成一次复现、案例拆解或实验草稿，并写清结果和失败原因。"
        default:
            return "把「\(topic)」沉淀成明确交付物，说明它如何服务 \(direction)。"
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
        guard item.contains("目标："),
              item.contains("具体执行计划："),
              item.contains("产出："),
              item.contains("\n1. "),
              item.contains("（"),
              item.contains("）"),
              let goalRange = item.range(of: "目标："),
              let executionRange = item.range(of: "具体执行计划：")
        else {
            return false
        }

        let objective = String(item[goalRange.upperBound..<executionRange.lowerBound])
        let execution = item[executionRange.upperBound...]
        if objective.contains("目标：") || objective.range(of: #"第\s*\d+\s*阶段"#, options: .regularExpression) != nil {
            return false
        }
        return !goalCandidates(objective).isEmpty &&
            execution.contains("Week") &&
            execution.contains("Day") &&
            executionCoversPhase(item: item, execution: String(execution)) &&
            ["目标：", "具体执行计划：", "产出："].allSatisfy { marker in
                guard let range = item.range(of: marker) else { return false }
                return item[range.upperBound...].contains("\n1. ")
            }
    }

    private static func executionCoversPhase(item: String, execution: String) -> Bool {
        let title = item.components(separatedBy: .newlines).first ?? ""
        let durationWeeks = phaseDurationWeeks(title)
        return highestWeekNumber(in: execution) >= durationWeeks
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

    private static func phaseDurationWeeks(_ timeRange: String) -> Int {
        if let weeks = rangeSpan(timeRange, unit: "周") {
            return weeks
        }
        if let months = rangeSpan(timeRange, unit: "个月") ?? rangeSpan(timeRange, unit: "月") {
            return months * 4
        }
        return 2
    }

    private static func rangeSpan(_ text: String, unit: String) -> Int? {
        let escapedUnit = NSRegularExpression.escapedPattern(for: unit)
        if let range = text.range(of: #"第\s*(\d+)\s*[-—~～至到]\s*(\d+)\s*"# + escapedUnit, options: .regularExpression) {
            let value = String(text[range])
            let numbers = numbers(in: value)
            if numbers.count >= 2 {
                return max(numbers[1] - numbers[0] + 1, 1)
            }
        }
        if text.range(of: #"第\s*\d+\s*"# + escapedUnit, options: .regularExpression) != nil {
            return 1
        }
        return nil
    }

    private static func highestWeekNumber(in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"Week\s+\d+(?:\s*[-—~～至到]\s*(\d+))?"#) else {
            return 0
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range)
            .compactMap { match -> Int? in
                guard let matchRange = Range(match.range, in: text) else { return nil }
                return numbers(in: String(text[matchRange])).last
            }
            .max() ?? 0
    }

    private static func numbers(in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: #"\d+"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return Int(String(text[matchRange]))
        }
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
