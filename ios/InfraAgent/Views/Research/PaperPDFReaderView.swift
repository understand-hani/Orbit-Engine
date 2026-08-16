import Foundation
import PDFKit
import SwiftUI

struct PaperPDFReaderView: View {
    let reader: PaperReader

    @State private var localURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let localURL {
                PDFKitView(documentURL: localURL)
                    .ignoresSafeArea(edges: .bottom)
            } else if isLoading {
                LoadingView(title: "Loading PDF...")
            } else if let errorMessage {
                EmptyStateView(
                    title: "PDF unavailable",
                    systemImage: "doc.richtext",
                    message: errorMessage
                )
            } else {
                EmptyStateView(
                    title: "No PDF",
                    systemImage: "doc",
                    message: "This paper does not have an available PDF URL yet."
                )
            }
        }
        .navigationTitle("PDF")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPDF()
        }
    }

    private func loadPDF() async {
        isLoading = true
        defer { isLoading = false }

        do {
            localURL = try await PaperPDFLoader.localURL(for: reader)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum PaperPDFLoader {
    static func localURL(for reader: PaperReader) async throws -> URL {
        if !reader.pdfLocalPath.isEmpty {
            let local = URL(fileURLWithPath: reader.pdfLocalPath)
            if FileManager.default.fileExists(atPath: local.path), PDFDocument(url: local) != nil {
                return local
            }
        }

        let destination = cachedURL(paperID: reader.paperID)
        if FileManager.default.fileExists(atPath: destination.path), PDFDocument(url: destination) != nil {
            return destination
        }

        guard let remoteURL = reader.pdfURL else {
            throw PaperPDFLoadError.missingURL
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: remoteURL, timeoutInterval: 60)
        request.setValue("OrbitEngine/0.1 (PDF reader)", forHTTPHeaderField: "User-Agent")

        let (downloadURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw PaperPDFLoadError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard isPDFFile(downloadURL) else {
            throw PaperPDFLoadError.invalidPDF
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: downloadURL, to: destination)
        guard PDFDocument(url: destination) != nil else {
            throw PaperPDFLoadError.invalidPDF
        }
        return destination
    }

    private static func cachedURL(paperID: String) -> URL {
        let safeID = paperID.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "_"
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(String(safeID))
            .appendingPathExtension("pdf")
    }

    private static func isPDFFile(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        do {
            let header = try handle.read(upToCount: 5) ?? Data()
            return String(data: header, encoding: .ascii) == "%PDF-"
        } catch {
            return false
        }
    }
}

enum PaperPDFLoadError: LocalizedError {
    case missingURL
    case badResponse(Int)
    case invalidPDF

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "这篇论文没有可用的 PDF 地址。"
        case .badResponse(let status):
            return "PDF 下载失败（HTTP \(status)）。可以先使用“打开论文页面”检查 arXiv 是否可访问。"
        case .invalidPDF:
            return "下载结果不是有效 PDF，可能被网络提示页或访问限制替换。"
        }
    }
}

struct PDFReadingSignals {
    let selectedPassages: [SelectedPassage]
    let keyFigures: [KeyFigure]
}

enum PDFReadingSignalExtractor {
    private struct PassageCandidate {
        let page: Int
        let text: String
        let score: Int
        let matchedTerms: [String]
    }

    static func extract(from documentURL: URL, paper: Paper) throws -> PDFReadingSignals {
        guard let document = PDFDocument(url: documentURL), document.pageCount > 0 else {
            throw PaperPDFLoadError.invalidPDF
        }

        let terms = searchTerms(for: paper)
        var passageCandidates: [PassageCandidate] = []
        var figureCaptions: [(page: Int, caption: String)] = []

        for pageIndex in 0..<min(document.pageCount, 40) {
            guard let rawText = document.page(at: pageIndex)?.string else { continue }
            for chunk in paragraphChunks(rawText) {
                let lowered = chunk.lowercased()
                let matched = terms.filter { lowered.contains($0.lowercased()) }
                let evidenceBonus = ["method", "result", "experiment", "evaluation", "we propose", "our approach"]
                    .filter { lowered.contains($0) }
                    .count
                passageCandidates.append(
                    PassageCandidate(
                        page: pageIndex + 1,
                        text: chunk,
                        score: matched.count * 4 + evidenceBonus,
                        matchedTerms: Array(matched.prefix(4))
                    )
                )
            }
            figureCaptions.append(contentsOf: captions(in: rawText).map { (pageIndex + 1, $0) })
        }

        let selected = passageCandidates
            .filter { $0.text.count >= 120 }
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.page < rhs.page : lhs.score > rhs.score
            }
            .reduce(into: [PassageCandidate]()) { result, candidate in
                guard result.count < 3,
                      !result.contains(where: { $0.text == candidate.text }) else { return }
                result.append(candidate)
            }

        let passages = selected.enumerated().map { index, candidate in
            SelectedPassage(
                id: "\(paper.id)_pdf_passage_\(index + 1)",
                paperID: paper.id,
                page: candidate.page,
                sectionName: "PDF 第 \(candidate.page) 页",
                textExcerpt: candidate.text,
                whySelected: candidate.matchedTerms.isEmpty
                    ? "该段来自真实 PDF 正文，包含较完整的方法或证据描述。"
                    : "该段来自真实 PDF 正文，并直接覆盖 \(candidate.matchedTerms.joined(separator: "、"))。",
                readingQuestion: "这段论述的问题、方法假设、证据和适用边界分别是什么？",
                status: "unread"
            )
        }

        var seenCaptions = Set<String>()
        let figures = figureCaptions.compactMap { item -> (Int, String)? in
            let key = item.caption.lowercased()
            guard seenCaptions.insert(key).inserted else { return nil }
            return item
        }
        .prefix(3)
        .enumerated()
        .map { index, item in
            let label = figureLabel(from: item.1) ?? "图表 \(index + 1)"
            return KeyFigure(
                id: "\(paper.id)_pdf_figure_\(index + 1)",
                paperID: paper.id,
                page: item.0,
                figureLabel: label,
                visual: VisualAsset(
                    id: "\(paper.id)_pdf_visual_\(index + 1)",
                    type: .pdfFigure,
                    url: nil,
                    localPath: documentURL.path,
                    caption: item.1,
                    source: paper.title,
                    usage: .methodFigure
                ),
                whyImportant: "该图表标题来自真实 PDF，可用于核对方法结构、实验设置或主要结果。",
                readingQuestion: "这张图表支持了论文的哪项结论，横纵轴、模块或对照组分别代表什么？"
            )
        }

        return PDFReadingSignals(selectedPassages: passages, keyFigures: Array(figures))
    }

    private static func searchTerms(for paper: Paper) -> [String] {
        let raw = ([paper.title] + paper.tags)
            .joined(separator: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 }
        let generic = Set(["with", "from", "using", "based", "paper", "arxiv", "model", "models"])
        var seen = Set<String>()
        return raw.filter { generic.contains($0.lowercased()) == false && seen.insert($0.lowercased()).inserted }
    }

    private static func paragraphChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        var buffer = ""

        func flush() {
            let cleaned = buffer.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count >= 120 {
                chunks.append(String(cleaned.prefix(700)))
            }
            buffer = ""
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flush()
                continue
            }
            buffer += buffer.isEmpty ? line : " \(line)"
            if buffer.count >= 480 {
                flush()
            }
        }
        flush()
        return chunks
    }

    private static func captions(in text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { rawLine in
            let line = rawLine.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 12, line.count <= 500,
                  line.range(of: #"^(Figure|Fig\.?|Table)\s*\d+"#, options: [.regularExpression, .caseInsensitive]) != nil else {
                return nil
            }
            return line
        }
    }

    private static func figureLabel(from caption: String) -> String? {
        guard let range = caption.range(
            of: #"^(Figure|Fig\.?|Table)\s*\d+"#,
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }
        return String(caption[range])
    }
}
