import PDFKit
import SwiftUI

struct PDFKitView: UIViewRepresentable {
    let documentURL: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.document = PDFDocument(url: documentURL)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != documentURL {
            uiView.document = PDFDocument(url: documentURL)
        }
    }
}
