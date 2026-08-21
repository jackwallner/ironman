import SwiftUI

/// The card Pattie appears in.
///
/// It sits above the tab bar rather than over the middle of the screen: this
/// interrupts on purpose, but it should never cover the split someone is
/// reading. Tapping anywhere dismisses, and it clears itself after a beat so an
/// unnoticed one doesn't sit there for the rest of the session.
struct PattiePopup: View {
    let line: PattieMode.Line
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(line.portrait)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(TriPalette.sunrise, lineWidth: 2))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("TRI PATTIE'S POINTERS")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.sunrise)
                Text(line.text)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkOnDark)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(TriPalette.deep)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        )
        .padding(.horizontal, 14)
        .offset(y: appeared ? 0 : 140)
        .opacity(appeared ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pattie says: \(line.text)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Dismiss", onDismiss)
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { appeared = true }
            // Long enough to read two lines out loud, then it leaves.
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            onDismiss()
        }
    }
}

extension View {
    /// Host Pattie's card over this view. Attach once, at the root.
    func pattieHost(_ pattie: PattieMode) -> some View {
        overlay(alignment: .bottom) {
            if let line = pattie.current {
                PattiePopup(line: line) { pattie.dismiss() }
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
    }

    /// Offer a moment when this view appears.
    func pattieMoment(_ moment: PattieMode.Moment, _ pattie: PattieMode) -> some View {
        task { pattie.fire(moment) }
    }
}
