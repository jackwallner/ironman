import PDFKit
import SwiftUI

/// A local document viewer for the Race Book. The file never has to leave the
/// phone before the athlete can inspect it.
struct RaceBookPDFPreview: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RaceBookPDFDocument(url: url)
                .background(TriPalette.canvas)
                .navigationTitle("Race Book PDF")
                .navigationBarTitleDisplayMode(.inline)
                .triNavBar()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(TriType.bodyBold)
                                .foregroundStyle(TriPalette.inkOnDark)
                                .padding(.horizontal, TriSpace.x3)
                                .frame(minHeight: TriGeo.tapTarget)
                        }
                        .buttonStyle(.triPressSilent)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(TriType.bodyBold)
                                .foregroundStyle(TriPalette.inkOnDark)
                                .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
                        }
                        .accessibilityLabel("Share PDF")
                    }
                }
        }
    }
}

private struct RaceBookPDFDocument: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)
        view.backgroundColor = .systemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
        view.autoScales = true
    }
}
