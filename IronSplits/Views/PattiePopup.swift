import SwiftUI

/// Pattie's persistent companion. Her face stays put, while one small speech
/// bubble and one visual state react to the moment in front of the athlete.
struct PattieCompanion: View {
    let line: PattieMode.Line?
    let onReplay: () -> Void
    let onDismiss: () -> Void
    let onInvite: () -> Void

    @ObservedObject private var voice = PattieVoice.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var idleBreathe = false
    @State private var animationTrigger = 0

    /// The companion is hosted above the tab bar and the device safe area.
    static let tabBarHeight: CGFloat = 49
    static let tabBarGap: CGFloat = TriSpace.x3
    private static let avatarSize: CGFloat = TriSpace.x10 + TriSpace.x4

    private var petState: PattiePetState { line?.petState ?? .idle }
    private var isSpeaking: Bool { voice.isPlaying(line?.voice) }

    var body: some View {
        HStack(alignment: .bottom, spacing: TriSpace.x2) {
            avatar
            if let line {
                speechBubble(for: line)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(.horizontal, TriSpace.x3)
        .offset(y: appeared ? 0 : TriSpace.x3)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                   value: line?.id)
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                idleBreathe = true
            }
            animationTrigger += 1
        }
        .onChange(of: line?.id) { _, _ in
            guard !reduceMotion else { return }
            animationTrigger += 1
        }
        .task(id: line?.id) { await run(line: line) }
    }

    private var avatar: some View {
        Button(action: line == nil ? onInvite : onReplay) {
            ZStack {
                Circle()
                    .fill(TriPalette.deep)
                    .overlay(Circle().stroke(TriPalette.sunrise, lineWidth: TriGeo.hairline))

                petImage

                if let symbol = petState.accessorySymbol {
                    accessory(symbol)
                }

                Circle()
                    .stroke(TriPalette.sunrise.opacity(isSpeaking ? 0.58 : 0.32),
                            lineWidth: TriSpace.x1)
                    .scaleEffect(isSpeaking ? 1.12 : 1)
                    .opacity(isSpeaking ? 0 : 1)

                speakerPip
            }
            .frame(width: Self.avatarSize, height: Self.avatarSize)
        }
        .buttonStyle(.triPressSilent)
        .accessibilityIdentifier("pattie-avatar")
        .accessibilityLabel(line == nil ? "Pattie, hear a tip" : "Pattie, replay")
        .accessibilityValue("State: \(petState.rawValue)")
    }

    @ViewBuilder
    private var petImage: some View {
        let image = Image(petState.imageName)
            .resizable()
            .scaledToFill()
            .frame(width: Self.avatarSize, height: Self.avatarSize)
            .scaleEffect(1.55)
            .offset(y: -TriSpace.x2)
            .clipShape(Circle())

        if reduceMotion {
            image
        } else {
            image
                .phaseAnimator([false, true], trigger: animationTrigger) { content, phase in
                    content
                        .offset(y: phase ? -TriSpace.x1 : 0)
                        .rotationEffect(.degrees(phase ? rotation(for: petState) : 0))
                } animation: { _ in
                    .spring(response: 0.42, dampingFraction: 0.68)
                }
                .offset(y: line == nil && idleBreathe ? -TriSpace.x1 / 2 : 0)
        }
    }

    private func rotation(for state: PattiePetState) -> Double {
        switch state {
        case .celebrate: return -3
        case .shoes: return 3
        case .swim: return -2
        case .bike: return 2
        default: return 0
        }
    }

    @ViewBuilder
    private func accessory(_ symbol: String) -> some View {
        let icon = Image(systemName: symbol)
            .font(TriType.micro)
            .foregroundStyle(TriPalette.deep)
            .frame(width: TriSpace.x8, height: TriSpace.x8)
            .background(TriPalette.sunrise, in: Circle())
            .overlay(Circle().stroke(TriPalette.deep, lineWidth: TriGeo.hairline))
            .offset(x: TriSpace.x4, y: -TriSpace.x4)
            .accessibilityHidden(true)

        if reduceMotion {
            icon
        } else {
            icon
                .phaseAnimator([false, true], trigger: animationTrigger) { content, phase in
                    content
                        .offset(x: phase ? TriSpace.x1 : 0,
                                y: phase ? -TriSpace.x1 : 0)
                        .rotationEffect(.degrees(phase ? 8 : 0))
                } animation: { _ in
                    .spring(response: 0.48, dampingFraction: 0.7)
                }
        }
    }

    @ViewBuilder
    private var speakerPip: some View {
        if isSpeaking {
            Image(systemName: "waveform")
                .font(TriType.micro)
                .foregroundStyle(TriPalette.deep)
                .frame(width: TriSpace.x8, height: TriSpace.x8)
                .background(TriPalette.sunrise, in: Circle())
                .overlay(Circle().stroke(TriPalette.deep, lineWidth: TriGeo.hairline))
                .transition(.scale.combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }

    private func speechBubble(for line: PattieMode.Line) -> some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            HStack(spacing: TriSpace.x2) {
                Text("PATTIE")
                    .font(TriType.micro)
                    .kerning(1.2)
                    .foregroundStyle(TriPalette.sunrise)
                Rectangle()
                    .fill(TriPalette.hairline)
                    .frame(height: TriGeo.hairline)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
                }
                .buttonStyle(.triPressSilent)
                .accessibilityLabel("Dismiss Pattie")
            }

            Text(line.text)
                .font(TriType.small)
                .foregroundStyle(TriPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("pattie-bubble")
                .accessibilityLabel("Pattie says: \(line.text)")
                .onTapGesture(perform: onDismiss)

            HStack(spacing: TriSpace.x2) {
                Text(isSpeaking ? "In her own voice" : "Tap the face to replay")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .animation(.easeInOut(duration: 0.2), value: isSpeaking)

                Spacer(minLength: 0)

                Button(action: onReplay) {
                    Image(systemName: isSpeaking ? "waveform" : "play.fill")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.deep)
                        .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
                        .background(TriPalette.sunrise, in: Circle())
                }
                .buttonStyle(.triPressSilent)
                .accessibilityIdentifier("pattie-replay")
                .accessibilityLabel(isSpeaking ? "Stop Pattie" : "Hear Pattie")
            }
        }
        .padding(TriSpace.x3)
        .frame(maxWidth: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                .fill(TriPalette.surface)
                .shadow(color: TriShadow.floating(scheme).0,
                        radius: TriShadow.floating(scheme).1,
                        y: TriShadow.floating(scheme).2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                .stroke(TriPalette.sunrise.opacity(0.45), lineWidth: TriGeo.hairline)
        )
        .contentShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
    }

    private func run(line: PattieMode.Line?) async {
        if reduceMotion { appeared = true }
        guard let line else { return }

        let readingTime = min(7.0, max(3.0, 2.0 + Double(line.text.count) / 28.0))
        do {
            try await Task.sleep(for: .seconds(readingTime))
            while voice.isPlaying(line.voice) {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(400))
            }
        } catch {
            return
        }

        guard !Task.isCancelled, self.line?.id == line.id else { return }
        onDismiss()
    }
}

extension View {
    /// Host Pattie's companion above the tab bar without changing app layout.
    func pattieHost(_ pattie: PattieMode) -> some View {
        modifier(PattieHostModifier(pattie: pattie))
    }

    /// Offer a moment when this view appears.
    func pattieMoment(_ moment: PattieMode.Moment, _ pattie: PattieMode) -> some View {
        task { pattie.fire(moment) }
    }
}

private struct PattieHostModifier: ViewModifier {
    @ObservedObject var pattie: PattieMode

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomLeading) {
            if pattie.isEnabled {
                PattieCompanion(
                    line: pattie.current,
                    onReplay: { pattie.replayVoice() },
                    onDismiss: { pattie.dismiss() },
                    onInvite: { pattie.demo() }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, PattieCompanion.tabBarHeight + PattieCompanion.tabBarGap)
                .safeAreaPadding(.bottom)
                .zIndex(10)
            }
        }
    }
}
