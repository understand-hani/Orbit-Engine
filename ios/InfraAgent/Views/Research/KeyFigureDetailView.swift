import PDFKit
import SwiftUI
import UIKit

struct KeyFigureDetailView: View {
    let session: BaseSession
    let paperID: String
    let figure: KeyFigure

    var body: some View {
        List {
            Section("图") {
                Text(figure.figureLabel.isEmpty ? "关键图" : figure.figureLabel)
                    .font(.headline)
                if let page = figure.page {
                    LabeledContent("页码", value: "\(page)")
                }
                if !figure.visual.localPath.isEmpty {
                    PDFKeyFigureSnapshotView(
                        documentURL: URL(fileURLWithPath: figure.visual.localPath),
                        pageNumber: figure.page,
                        caption: figure.visual.caption,
                        visualType: figure.visual.type.rawValue
                    )
                    .frame(minHeight: 420)
                }
            }

            Section("Agent 分析") {
                Text(figure.whyImportant)
            }

            Section("阅读问题") {
                Text(figure.readingQuestion)
            }

            Section("Agent 讨论") {
                NavigationLink {
                    AgentChatView(
                        session: session,
                        contextRefs: [paperID, figure.id],
                        title: "Agent 讨论"
                    )
                } label: {
                    Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                }
            }

        }
        .navigationTitle("图")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PDFKeyFigureSnapshotView: View {
    let documentURL: URL
    let pageNumber: Int?
    let caption: String
    let visualType: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 260)
            }
        }
        .task(id: "\(documentURL.path)-\(pageNumber ?? 0)-\(caption)") {
            image = PDFKeyFigureRenderer.render(
                documentURL: documentURL,
                pageNumber: pageNumber,
                caption: caption,
                visualType: visualType
            )
        }
    }
}

private enum PDFKeyFigureRenderer {
    static func render(documentURL: URL, pageNumber: Int?, caption: String, visualType: String) -> UIImage? {
        guard let document = PDFDocument(url: documentURL), document.pageCount > 0 else {
            return nil
        }
        let pageIndex = max(0, min((pageNumber ?? 1) - 1, document.pageCount - 1))
        guard let page = document.page(at: pageIndex) else {
            return nil
        }

        let pageBounds = page.bounds(for: .mediaBox)
        let cropBounds = figureCropBounds(page: page, pageBounds: pageBounds, caption: caption, visualType: visualType)
        return render(page: page, cropBounds: cropBounds)
    }

    private static func figureCropBounds(
        page: PDFPage,
        pageBounds: CGRect,
        caption: String,
        visualType: String
    ) -> CGRect {
        guard let captionBounds = captionBounds(page: page, caption: caption) else {
            return centeredVisualBounds(pageBounds: pageBounds)
        }

        let marginX = pageBounds.width * 0.06
        let minY = pageBounds.minY + pageBounds.height * 0.06
        let maxY = pageBounds.maxY - pageBounds.height * 0.06
        let x = pageBounds.minX + marginX
        let width = pageBounds.width - marginX * 2
        let maxHeight = pageBounds.height * 0.48

        if visualType == "table" {
            let top = min(maxY, captionBounds.minY - pageBounds.height * 0.02)
            let bottom = max(minY, top - maxHeight)
            return CGRect(x: x, y: bottom, width: width, height: top - bottom).standardized
        }

        let bottom = min(maxY, captionBounds.maxY + pageBounds.height * 0.02)
        let top = min(maxY, bottom + maxHeight)
        return CGRect(x: x, y: bottom, width: width, height: top - bottom).standardized
    }

    private static func captionBounds(page: PDFPage, caption: String) -> CGRect? {
        guard let pageText = page.string else {
            return nil
        }

        let candidates = captionCandidates(from: caption)
        for candidate in candidates {
            guard let range = pageText.range(of: candidate, options: [.caseInsensitive]),
                  let selection = page.selection(for: NSRange(range, in: pageText)) else {
                continue
            }
            let bounds = selection.bounds(for: page).standardized
            if bounds.width > 0, bounds.height > 0 {
                return bounds
            }
        }
        return nil
    }

    private static func captionCandidates(from caption: String) -> [String] {
        let normalized = caption
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return []
        }

        var candidates = [normalized]
        if let labelRange = normalized.range(
            of: #"^(Figure|Fig\.?|Table)\s*\d+[A-Za-z]?"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            candidates.append(String(normalized[labelRange]))
        }
        let words = normalized.split(separator: " ").map(String.init)
        if words.count > 12 {
            candidates.append(words.prefix(12).joined(separator: " "))
        }
        if words.count > 6 {
            candidates.append(words.prefix(6).joined(separator: " "))
        }
        return candidates
    }

    private static func centeredVisualBounds(pageBounds: CGRect) -> CGRect {
        let width = pageBounds.width * 0.88
        let height = pageBounds.height * 0.46
        return CGRect(
            x: pageBounds.midX - width / 2,
            y: pageBounds.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func render(page: PDFPage, cropBounds: CGRect) -> UIImage? {
        let scale: CGFloat = 2
        let outputSize = CGSize(width: cropBounds.width, height: cropBounds.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.translateBy(x: -cropBounds.minX, y: cropBounds.height + cropBounds.minY)
            cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()
        }
    }
}
