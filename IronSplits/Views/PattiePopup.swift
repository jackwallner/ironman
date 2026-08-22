import SwiftUI

/// Pattie's persistent companion. Real portraits, a loud mode flag, and one
/// oversized speech card make the feature impossible to miss when it is on.
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
    private static let avatarWidth: CGFloat = TriSpace.x10 * 3
    private static let avatarHeight: CGFloat = TriSpace.x10 * 4
    private static let avatarFrameWidth: CGFloat = avatarWidth + TriSpace.x4
    private static let avatarFrameHeight: CGFloat = avatarHeight + TriSpace.x2
    private static let idleStates: [PattiePetState] = [
        .idle, .coach, .encourage, .celebrate, .bike
    ]
    private static let idlePortraits = [
        "pattie-profile", "pattie-ready", "pattie-excited", "pattie-grit", "pattie-ride"
    ]

    private var petState: PattiePetState { line?.petState ?? idleState }
    private var portraitName: String {
        line?.portrait ?? Self.idlePortraits[idleIndex]
    }
    private var isSpeaking: Bool { voice.isPlaying(line?.voice) }

    var body: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            modeBanner

            HStack(alignment: .bottom, spacing: TriSpace.x2) {
                avatar
                if let line {
                    speechBubble(for: line)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
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

    private var modeBanner: some View {
        HStack(spacing: TriSpace.x2) {
            Image(systemName: "waveform.circle.fill")
                .accessibilityHidden(true)
            Text("PATTIE MODE")
                .kerning(1.1)
            Text(line == nil ? "ON" : "LIVE")
                .font(TriType.micro)
                .padding(.horizontal, TriSpace.x2)
                .padding(.vertical, TriSpace.x1)
                .background(TriPalette.deep.opacity(0.14), in: Capsule())
        }
        .font(TriType.micro)
        .foregroundStyle(TriPalette.deep)
        .padding(.horizontal, TriSpace.x3)
        .frame(minHeight: TriSpace.x8)
        .background(TriPalette.sunrise, in: Capsule())
        .overlay(Capsule().stroke(TriPalette.deep.opacity(0.36), lineWidth: TriGeo.hairline))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pattie Mode \(line == nil ? "on" : "live")")
    }

    private var avatar: some View {
        Button(action: line == nil ? onInvite : onReplay) {
            ZStack(alignment: .bottom) {
                pattiePhoto
                    .overlay(alignment: .topTrailing) {
                        if let symbol = petState.accessorySymbol {
                            accessory(symbol)
                                .offset(x: TriSpace.x1, y: -TriSpace.x1)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isSpeaking {
                            speakerPip
                                .offset(x: TriSpace.x1, y: -TriSpace.x4)
                        }
                    }
            }
            .frame(width: Self.avatarFrameWidth, height: Self.avatarFrameHeight, alignment: .bottom)
        }
        .buttonStyle(.triPressSilent)
        .accessibilityIdentifier("pattie-avatar")
        .accessibilityLabel(line == nil ? "Pattie, hear a tip" : "Pattie, replay her real voice")
        .accessibilityValue("Real photo, \(petState.accessibilityName)")
    }

    private var photoContent: some View {
        ZStack(alignment: .bottom) {
            Image(portraitName)
                .resizable()
                .scaledToFill()
                .frame(width: Self.avatarWidth, height: Self.avatarHeight)
                .clipped()

            LinearGradient(
                colors: [TriPalette.deep.opacity(0), TriPalette.deep.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .center, spacing: TriSpace.x2) {
                Text("PATTIE")
                    .font(TriType.micro)
                    .kerning(1)
                Spacer(minLength: 0)
                Text(isSpeaking ? "LIVE" : "REAL")
                    .font(TriType.micro)
            }
            .foregroundStyle(TriPalette.inkOnDark)
            .padding(.horizontal, TriSpace.x3)
            .padding(.vertical, TriSpace.x2)
        }
        .background(TriPalette.deep)
        .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                .stroke(TriPalette.sunrise, lineWidth: TriSpace.x1)
        )
        .offset(y: line == nil && idleBreathe ? -TriSpace.x1 / 2 : 0)
    }

    @ViewBuilder
    private var pattiePhoto: some View {
        if reduceMotion {
            photoContent
        } else {
            photoContent
                .phaseAnimator([false, true], trigger: animationTrigger) { content, phase in
                    content
                        .offset(y: phase ? -TriSpace.x1 : 0)
                        .rotationEffect(.degrees(phase ? rotation(for: petState) : 0))
                } animation: { _ in
                    .spring(response: 0.42, dampingFraction: 0.68)
                }
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
            .font(TriType.smallBold)
            .foregroundStyle(TriPalette.deep)
            .frame(width: TriSpace.x10, height: TriSpace.x10)
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
                .font(TriType.smallBold)
                .foregroundStyle(TriPalette.deep)
                .frame(width: TriSpace.x10, height: TriSpace.x10)
                .background(TriPalette.sunrise, in: Circle())
                .overlay(Circle().stroke(TriPalette.deep, lineWidth: TriGeo.hairline))
                .transition(.scale.combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }

    private func speechBubble(for line: PattieMode.Line) -> some View {
        VStack(alignment: .leading, spacing: TriSpace.x4) {
            HStack(spacing: TriSpace.x2) {
                Text("PATTIE MODE")
                    .font(TriType.sectionTitle)
                    .kerning(1.1)
                    .foregroundStyle(TriPalette.sunrise)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(TriType.smallBold)
                        .foregroundStyle(TriPalette.inkOnDark)
                        .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
                        .background(TriPalette.inkOnDark.opacity(0.12), in: Circle())
                }
                .buttonStyle(.triPressSilent)
                .accessibilityLabel("Dismiss Pattie")
            }

            HStack(spacing: TriSpace.x2) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(TriPalette.sunrise)
                    .accessibilityHidden(true)

                Text("ROTATING PHRASES")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)

                Text(isSpeaking ? "LIVE" : "READY")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.deep)
                    .padding(.horizontal, TriSpace.x2)
                    .padding(.vertical, TriSpace.x1)
                    .background(TriPalette.sunrise, in: Capsule())
            }

            HStack(alignment: .top, spacing: TriSpace.x2) {
                Text("“")
                    .font(TriType.pageTitle)
                    .foregroundStyle(TriPalette.sunrise)
                    .accessibilityHidden(true)

                Text(line.text)
                    .font(TriType.bodyBold)
                    .foregroundStyle(TriPalette.inkOnDark)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier("pattie-bubble")
                    .accessibilityLabel("Pattie says: \(line.text)")
                    .onTapGesture(perform: onDismiss)
            }

            HStack(alignment: .center, spacing: TriSpace.x2) {
                Image(systemName: "waveform")
                    .foregroundStyle(TriPalette.sunrise)
                    .accessibilityHidden(true)

                Text(isSpeaking ? "PATTIE IS TALKING" : "REAL PATTIE AUDIO")
                    .font(TriType.micro)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.78))
                    .animation(.easeInOut(duration: 0.2), value: isSpeaking)

                Spacer(minLength: 0)

                Button(action: onReplay) {
                    Label(isSpeaking ? "Stop" : "Replay", systemImage: isSpeaking ? "stop.fill" : "play.fill")
                        .font(TriType.smallBold)
                        .foregroundStyle(TriPalette.deep)
                        .padding(.horizontal, TriSpace.x3)
                        .frame(minHeight: TriGeo.tapTarget)
                        .background(TriPalette.sunrise, in: Capsule())
                }
                .buttonStyle(.triPressSilent)
                .accessibilityIdentifier("pattie-replay")
                .accessibilityLabel(isSpeaking ? "Stop Pattie" : "Hear Pattie")
            }
        }
        .padding(TriSpace.x5)
        .frame(maxWidth: TriSpace.x10 * 9, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                .fill(TriPalette.deep)
                .shadow(color: TriShadow.floating(scheme).0,
                        radius: TriShadow.floating(scheme).1,
                        y: TriShadow.floating(scheme).2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                .stroke(TriPalette.sunrise, lineWidth: TriSpace.x1)
        )
        .contentShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
    }

    private func run(line: PattieMode.Line?) async {
        if reduceMotion { appeared = true }
        guard let line else { return }

        let readingTime = min(10.0, max(4.0, 2.5 + Double(line.text.count) / 26.0))
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
                .padding(.bottom,
                         PattieCompanion.tabBarHeight + PattieCompanion.tabBarGap + TriSpace.x4)
                .safeAreaPadding(.bottom)
                .zIndex(10)
            }
        }
    }
}
