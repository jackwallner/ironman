import SwiftUI

/// The card Pattie appears in.
///
/// The old one was a 56pt thumbnail in a thin banner, which is roughly the
/// weight of a push notification about a software update. This is the opposite
/// bet: she arrives at the size of a person, the portrait leans in from the
/// edge as if she has stepped into frame, and the ring around her pulses while
/// her voice is actually playing so the audio and the picture are obviously the
/// same event.
///
/// `.big` moments dim the screen behind her; `.banner` moments do not, and stay
/// out of the way of whatever split someone is reading. Both dismiss on tap, on
/// a downward drag, and on a timer sized to how long the clip runs.
struct PattiePopup: View {
    let line: PattieMode.Line
    let onReplay: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var voice = PattieVoice.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0
    @State private var pulse = false

    /// Tab bar (49pt) plus the home indicator inset plus a gap on the scale.
    static let tabBarClearance: CGFloat = 49 + 34 + TriSpace.x3

    private var isBig: Bool { line.impact == .big }
    private var portraitSize: CGFloat { isBig ? 116 : 76 }
    private var isSpeaking: Bool { voice.isPlaying(line.voice) }

    var body: some View {
        VStack(spacing: 0) {
            card
        }
        .padding(.horizontal, TriSpace.x3)
        .offset(y: appeared ? dragOffset : 220)
        .opacity(appeared ? 1 : 0)
        .gesture(dismissDrag)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pattie says: \(line.text)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Replay", onReplay)
        .accessibilityAction(named: "Dismiss", onDismiss)
        .task { await run() }
    }

    // MARK: - Card

    private var card: some View {
        HStack(alignment: .top, spacing: TriSpace.x3) {
            portrait
            bubble
        }
        .padding(TriSpace.x4)
        .background(
            RoundedRectangle(cornerRadius: TriGeo.radiusCard + TriSpace.x2, style: .continuous)
                .fill(TriPalette.deep)
                .overlay(
                    // A single warm sweep behind her, so the card reads as
                    // sunrise-over-open-water rather than a grey system sheet.
                    RoundedRectangle(cornerRadius: TriGeo.radiusCard + TriSpace.x2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [TriPalette.sunrise.opacity(0.30), .clear],
                                startPoint: .topLeading,
                                endPoint: .init(x: 0.75, y: 0.9)
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TriGeo.radiusCard + TriSpace.x2, style: .continuous)
                        .stroke(TriPalette.sunrise.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: TriShadow.floating(scheme).0,
                        radius: TriShadow.floating(scheme).1,
                        y: TriShadow.floating(scheme).2)
        )
        .contentShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard + TriSpace.x2, style: .continuous))
        .onTapGesture(perform: onDismiss)
    }

    /// Tapping her replays the clip, which is the obvious thing to try when you
    /// caught the picture and missed the words.
    private var portrait: some View {
        Button(action: onReplay) {
            ZStack {
                Circle()
                    .stroke(TriPalette.sunrise.opacity(isSpeaking ? 0.55 : 0), lineWidth: 3)
                    .scaleEffect(pulse && isSpeaking ? 1.22 : 1.0)
                    .opacity(pulse && isSpeaking ? 0 : 1)

                Image(line.portrait)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: portraitSize, height: portraitSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(TriPalette.sunrise, lineWidth: isBig ? 3 : 2))
                    .overlay(alignment: .bottomTrailing) { speakerPip }
                    // She leans in from the left, then settles.
                    .rotationEffect(.degrees(appeared ? 0 : -12))
                    .scaleEffect(appeared ? 1 : 0.6)
            }
            .frame(width: portraitSize, height: portraitSize)
        }
        .buttonStyle(.triPressSilent)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var speakerPip: some View {
        if isSpeaking {
            Image(systemName: "waveform")
                .font(.system(size: isBig ? 13 : 11, weight: .bold))
                .foregroundStyle(TriPalette.deep)
                .frame(width: isBig ? 28 : 22, height: isBig ? 28 : 22)
                .background(TriPalette.sunrise, in: Circle())
                .overlay(Circle().stroke(TriPalette.deep, lineWidth: 2))
                .transition(.scale.combined(with: .opacity))
        } else {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: isBig ? 12 : 10, weight: .bold))
                .foregroundStyle(TriPalette.deep)
                .frame(width: isBig ? 26 : 20, height: isBig ? 26 : 20)
                .background(.white.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(TriPalette.deep, lineWidth: 2))
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            HStack(spacing: TriSpace.x2) {
                Text("PATTIE")
                    .font(TriType.micro)
                    .kerning(1.2)
                    .foregroundStyle(TriPalette.sunrise)
                Rectangle()
                    .fill(TriPalette.sunrise.opacity(0.35))
                    .frame(height: TriGeo.hairline)
            }

            Text(line.text)
                .font(isBig ? TriType.cardTitle : TriType.body)
                .foregroundStyle(TriPalette.inkOnDark)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Text(isSpeaking ? "In her own voice" : "Tap her to hear it")
                .font(TriType.micro)
                .foregroundStyle(.white.opacity(0.55))
                .animation(.easeInOut(duration: 0.2), value: isSpeaking)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Behaviour

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 60 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
                }
            }
    }

    private func run() async {
        if reduceMotion {
            appeared = true
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { appeared = true }
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true }
        }
        // Long enough to read it, and long enough for the clip to finish: the
        // solution clips run to sixteen seconds and cutting her off mid-sentence
        // is worse than no audio at all.
        let readingTime = min(11.0, 3.0 + Double(line.text.count) / 22.0)
        try? await Task.sleep(for: .seconds(readingTime))
        while voice.isPlaying(line.voice) {
            try? await Task.sleep(for: .milliseconds(400))
        }
        guard !Task.isCancelled else { return }
        onDismiss()
    }
}

extension View {
    /// Host Pattie's card over this view. Attach once, at the root.
    func pattieHost(_ pattie: PattieMode) -> some View {
        overlay {
            if let line = pattie.current {
                ZStack(alignment: .bottom) {
                    if line.impact == .big {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .onTapGesture { pattie.dismiss() }
                    }
                    PattiePopup(line: line,
                                onReplay: { pattie.replayVoice() },
                                onDismiss: { pattie.dismiss() })
                        // A banner clears the tab bar so it never covers a tab
                        // it is inviting you to go to. A big one sits lower,
                        // because it has already dimmed everything behind it.
                        .padding(.bottom, line.impact == .big ? TriSpace.x10 : PattiePopup.tabBarClearance)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(10)
            }
        }
    }

    /// Offer a moment when this view appears.
    func pattieMoment(_ moment: PattieMode.Moment, _ pattie: PattieMode) -> some View {
        task { pattie.fire(moment) }
    }
}
