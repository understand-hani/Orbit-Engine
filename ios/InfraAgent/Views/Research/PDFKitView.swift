import PDFKit
import SwiftUI

struct PDFKitView: UIViewRepresentable {
    let documentURL: URL
    var initialPage: Int? = nil

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        let document = PDFDocument(url: documentURL)
        pdfView.document = document
        if let initialPage,
           let page = document?.page(at: max(0, initialPage - 1)) {
            pdfView.go(to: page)
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != documentURL {
            uiView.document = PDFDocument(url: documentURL)
        }
    }
}
