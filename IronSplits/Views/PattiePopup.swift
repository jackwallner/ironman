import SwiftUI

/// Pattie's persistent companion. A small pet stays in the corner, and a tip
/// bubble appears only when she has something useful to say.
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
    @State private var idleState: PattiePetState = .idle
    @State private var idleIndex = 0

    /// The companion is hosted above the tab bar and the device safe area.
    static let tabBarHeight: CGFloat = 49
    static let tabBarGap: CGFloat = TriSpace.x3
    private static let avatarWidth: CGFloat = TriSpace.x10 + TriSpace.x10
    private static let avatarHeight: CGFloat = TriSpace.x10 + TriSpace.x10 + TriSpace.x10
    private static let avatarFrameWidth: CGFloat = avatarWidth + TriSpace.x4
    private static let avatarFrameHeight: CGFloat = avatarHeight + TriSpace.x2
    private static let idleStates: [PattiePetState] = [
        .idle, .coach, .encourage, .celebrate, .shoes, .swim, .bike
    ]

    private var petState: PattiePetState { line?.petState ?? idleState }

    var body: some View {
        HStack(alignment: .bottom, spacing: TriSpace.x2) {
            avatar
            if let line {
                speechBubble(for: line)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(.horizontal, TriSpace.x4)
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
        .task { await animateIdle() }
    }

    private var avatar: some View {
        Button(action: line == nil ? onInvite : onReplay) {
            ZStack(alignment: .bottom) {
                petImage
                    .overlay(alignment: .topTrailing) {
                        if let symbol = petState.accessorySymbol {
                            accessory(symbol)
                                .offset(x: TriSpace.x1, y: -TriSpace.x1)
                        }
                    }
            }
            .frame(width: Self.avatarFrameWidth, height: Self.avatarFrameHeight, alignment: .bottom)
        }
        .buttonStyle(.triPressSilent)
        .accessibilityIdentifier("pattie-avatar")
        .accessibilityLabel(line == nil ? "Pattie, hear a tip" : "Pattie, replay the tip")
        .accessibilityValue(petState.accessibilityName)
    }

    @ViewBuilder
    private var petImage: some View {
        let image = Image(petState.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: Self.avatarWidth, height: Self.avatarHeight, alignment: .bottom)

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

    private func speechBubble(for line: PattieMode.Line) -> some View {
        HStack(alignment: .top, spacing: TriSpace.x2) {
            Text(line.text)
                .font(TriType.body)
                .foregroundStyle(TriPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("pattie-bubble")
                .accessibilityLabel("Pattie says: \(line.text)")
                .onTapGesture(perform: onDismiss)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
            }
            .buttonStyle(.triPressSilent)
            .accessibilityLabel("Dismiss Pattie")
        }
        .padding(TriSpace.x4)
        .frame(maxWidth: TriSpace.x10 * 8, alignment: .leading)
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

        let readingTime = min(4.0, max(2.0, 1.5 + Double(line.text.count) / 80.0))
        do {
            try await Task.sleep(for: .seconds(readingTime))
            while voice.isPlaying(line.voice) {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(200))
            }
        } catch {
            return
        }

        guard !Task.isCancelled, self.line?.id == line.id else { return }
        onDismiss()
    }

    private func animateIdle() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(2.8))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) {
                idleIndex = (idleIndex + 1) % Self.idleStates.count
                idleState = Self.idleStates[idleIndex]
                animationTrigger += 1
            }
        }
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
