import Foundation
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
        if let fileURL = localFileURL(), FileManager.default.fileExists(atPath: fileURL.path) {
            localURL = fileURL
            return
        }

        guard let remoteURL = reader.pdfURL else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (downloadURL, _) = try await URLSession.shared.download(from: remoteURL)
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(reader.paperID)
                .appendingPathExtension("pdf")

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: downloadURL, to: destination)
            localURL = destination
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func localFileURL() -> URL? {
        guard !reader.pdfLocalPath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: reader.pdfLocalPath)
    }
}
