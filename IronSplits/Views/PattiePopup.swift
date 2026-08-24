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
    @State private var idleState: PattiePetState = .warmup
    @State private var idleIndex = 0
    @State private var animationStart = Date.now

    /// The companion is hosted above the tab bar and the device safe area.
    static let tabBarHeight: CGFloat = 49
    static let tabBarGap: CGFloat = TriSpace.x3
    private static let avatarWidth: CGFloat = TriSpace.x10 + TriSpace.x10
    private static let avatarHeight: CGFloat = TriSpace.x10 + TriSpace.x10 + TriSpace.x10
    private static let avatarFrameWidth: CGFloat = avatarWidth + TriSpace.x4
    private static let avatarFrameHeight: CGFloat = avatarHeight + TriSpace.x2
    private static let idleAvatarScale: CGFloat = 0.45
    private var petState: PattiePetState { line?.petState ?? idleState }
    private var avatarScale: CGFloat { line == nil ? Self.idleAvatarScale : 1 }

    var body: some View {
        companionContent
        .offset(y: appeared ? 0 : TriSpace.x3)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                   value: line?.text)
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
            animationStart = .now
        }
        .onChange(of: line?.text) { _, _ in
            animationStart = .now
        }
        .onChange(of: idleState) { _, _ in animationStart = .now }
        .task(id: line?.text) { await run(line: line) }
        .task { await animateIdle() }
    }

    @ViewBuilder
    private var companionContent: some View {
        if let line, line.isGiantCatchphrase {
            giantTakeover(for: line)
        } else {
            HStack(alignment: .bottom, spacing: TriSpace.x2) {
                avatar
                if let line {
                    speechBubble(for: line)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(.horizontal, TriSpace.x4)
        }
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
        .scaleEffect(avatarScale, anchor: .bottomLeading)
        .frame(width: Self.avatarFrameWidth * avatarScale,
               height: Self.avatarFrameHeight * avatarScale,
               alignment: .bottomLeading)
    }

    @ViewBuilder
    private var petImage: some View {
        if reduceMotion {
            petImage(for: petState.animationFrame(at: 0))
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSince(animationStart)
                petImage(for: petState.animationFrame(at: elapsed))
            }
        }
    }

    private func petImage(for frame: PattiePetState.MotionFrame) -> some View {
        Image(frame.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: Self.avatarWidth, height: Self.avatarHeight, alignment: .bottom)
            .offset(x: TriSpace.x1 * CGFloat(frame.horizontalShift),
                    y: -TriSpace.x1 * CGFloat(frame.verticalLift))
            .rotationEffect(.degrees(frame.rotationDegrees))
            .scaleEffect(frame.scale)
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
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSince(animationStart)
                let phase = sin(elapsed * 2 * .pi / 0.9)
                icon
                    .offset(x: TriSpace.x1 * CGFloat(phase),
                            y: -TriSpace.x1 * CGFloat(phase + 1) * 0.5)
                    .rotationEffect(.degrees(5 * phase))
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

    private func giantTakeover(for line: PattieMode.Line) -> some View {
        GeometryReader { proxy in
            ZStack {
                Button(action: onDismiss) {
                    Image("pattie-finish-cutout")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(proxy.size.width * 0.78, TriSpace.x10 * 8.5),
                               height: min(proxy.size.height * 0.78, TriSpace.x10 * 13.5))
                        .shadow(color: TriShadow.floating(scheme).0,
                                radius: TriShadow.floating(scheme).1,
                                y: TriShadow.floating(scheme).2)
                }
                .buttonStyle(.triPressSilent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, TriSpace.x2)
                .padding(.bottom, TriSpace.x2)
                .accessibilityLabel("Pattie, celebrate")

                VStack {
                    HStack {
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: TriSpace.x2) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("PATTIE MODE")
                                    .font(TriType.sectionTitle)
                                    .foregroundStyle(TriPalette.sunrise)
                                Spacer(minLength: TriSpace.x2)
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
                                .font(TriType.pageTitle)
                                .foregroundStyle(TriPalette.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.7)
                                .accessibilityIdentifier("pattie-giant-catchphrase")

                            Button("Keep moving", action: onDismiss)
                                .font(TriType.bodyBold)
                                .foregroundStyle(TriPalette.inkOnDark)
                                .frame(minHeight: TriGeo.tapTarget)
                                .padding(.horizontal, TriSpace.x4)
                                .background(TriPalette.sunrise, in: Capsule())
                                .buttonStyle(.triPressSilent)
                        }
                        .padding(TriSpace.x4)
                        .frame(maxWidth: min(proxy.size.width * 0.68, TriSpace.x10 * 7),
                               alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                                .fill(TriPalette.surface)
                                .shadow(color: TriShadow.floating(scheme).0,
                                        radius: TriShadow.floating(scheme).1,
                                        y: TriShadow.floating(scheme).2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                                .stroke(TriPalette.sunrise.opacity(0.55), lineWidth: TriGeo.hairline)
                        )
                    }
                    .padding(.horizontal, TriSpace.x4)
                    .padding(.top, TriSpace.x4)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pattie-giant-takeover")
        .accessibilityLabel("Pattie says: \(line.text)")
    }

    private func run(line: PattieMode.Line?) async {
        if reduceMotion { appeared = true }
        guard let line else { return }

        let minimumReadingTime = line.isGiantCatchphrase ? 3.2 : 2.0
        let maximumReadingTime = line.isGiantCatchphrase ? 5.0 : 4.0
        let readingTime = min(maximumReadingTime,
                              max(minimumReadingTime, 1.5 + Double(line.text.count) / 80.0))
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
            let nextState = PattiePetState.motionState(at: idleIndex)
            idleState = nextState
            idleIndex += 1

            do {
                let cadence = max(1.2, nextState.motionProfile.duration * 2.5)
                try await Task.sleep(for: .seconds(cadence))
            } catch {
                return
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
                if pattie.current?.isGiantCatchphrase == true {
                    companion
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(20)
                } else {
                    companion
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, PattieCompanion.tabBarHeight + PattieCompanion.tabBarGap)
                        .safeAreaPadding(.bottom)
                        .zIndex(10)
                }
            }
        }
    }

    private var companion: some View {
        PattieCompanion(
            line: pattie.current,
            onReplay: { pattie.replayVoice() },
            onDismiss: { pattie.dismiss() },
            onInvite: { pattie.demo() }
        )
    }
}
