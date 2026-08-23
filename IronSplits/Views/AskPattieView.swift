import SwiftUI

/// The loaded Ask Pattie tree, shared by the three screens that walk it.
///
/// One object rather than `@State` on each screen: the topic list and the answer
/// list are navigation destinations pushed onto the tab's stack, and a
/// destination that re-fetched the guide for itself would flash an empty screen
/// on every push.
@MainActor
final class AskPattieModel: ObservableObject {
    @Published private(set) var guide: AskPattieGuide = .empty
    @Published private(set) var isLoading = true

    func load() async {
        guide = await AskPattieLibrary.shared.guide()
        isLoading = false
        guide = await AskPattieLibrary.shared.refresh()
    }

    func refresh() async {
        guide = await AskPattieLibrary.shared.refresh(force: true)
    }
}

/// The two decisions, as navigation destinations, so back is the system back
/// button and the edge swipe works.
enum AskPattieStep: Hashable {
    case topics(goalID: String)
    case answers(goalID: String, topicID: String)
}

/// Step one: what are you training for?
///
/// Three taps, no text box, no model. This is a router into Pattie's existing
/// clips rather than a chat: it costs nothing per question, it cannot invent
/// coaching advice she never gave, and it answers on a start line with no
/// signal. See `AskPattieGuide`.
struct AskPattieGoalList: View {
    @ObservedObject var model: AskPattieModel
    @Binding var path: [AskPattieStep]
    @EnvironmentObject private var pattie: PattieMode

    var body: some View {
        if model.guide.goals.isEmpty && model.isLoading {
            ProgressView().tint(TriPalette.deep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.guide.goals.isEmpty {
            TriPlaceholder(systemImage: "questionmark.bubble",
                           title: "Ask Pattie isn't loaded",
                           message: "Pull down to fetch her pointers again.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: TriSpace.x3) {
                    PattieFeaturedHero()

                    Text(model.guide.subtitle)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TriSectionHeader(title: model.guide.goalQuestion)

                    ForEach(model.guide.goals) { goal in
                        Button {
                            pattie.react(.choice)
                            path.append(.topics(goalID: goal.id))
                        } label: {
                            AskPattieOptionRow(symbol: goal.symbol,
                                               title: goal.title,
                                               subtitle: goal.subtitle)
                        }
                        .buttonStyle(.triPress)
                    }
                }
                .padding(TriGeo.padPage)
            }
        }
    }
}

/// Step two: what do you need help with?
struct AskPattieTopicList: View {
    @ObservedObject var model: AskPattieModel
    @Binding var path: [AskPattieStep]
    @EnvironmentObject private var pattie: PattieMode
    let goalID: String

    var body: some View {
        let goal = model.guide.goal(goalID)
        ZStack {
            TriPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: TriSpace.x3) {
                    TriSectionHeader(title: "What do you need help with?", trailing: goal?.title)
                    ForEach(goal.map { model.guide.topics(for: $0) } ?? []) { topic in
                        let count = model.guide.answers(for: goalID, topic: topic.id).count
                        Button {
                            pattie.react(.choice)
                            path.append(.answers(goalID: goalID, topicID: topic.id))
                        } label: {
                            AskPattieOptionRow(symbol: topic.symbol,
                                               title: topic.title,
                                               subtitle: "\(count) pointer\(count == 1 ? "" : "s")")
                        }
                        .buttonStyle(.triPress)
                    }
                }
                .padding(TriGeo.padPage)
            }
        }
        .navigationTitle(goal?.title ?? "Ask Pattie")
        .navigationBarTitleDisplayMode(.inline)
        .triNavBar()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                TriBackButton()
            }
        }
    }
}

/// Step three: her pointers on exactly that.
struct AskPattieAnswerList: View {
    @ObservedObject var model: AskPattieModel
    @EnvironmentObject private var pattie: PattieMode

    let goalID: String
    let topicID: String

    var body: some View {
        ZStack {
            TriPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: TriSpace.x4) {
                    ForEach(model.guide.answers(for: goalID, topic: topicID)) { answer in
                        AskPattieAnswerCard(answer: answer)
                    }
                }
                .padding(TriGeo.padPage)
            }
        }
        .navigationTitle(model.guide.topic(topicID)?.title ?? "Pointers")
        .navigationBarTitleDisplayMode(.inline)
        .triNavBar()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                TriBackButton()
            }
        }
        .task { pattie.fire(.askAnswered, petState: .forTopicID(topicID)) }
        .onDisappear {
            // Replace the answer clip with a useful back-navigation reaction.
            // The parent path observer may also see this pop, but the action
            // cooldown makes the two paths collapse to one line.
            PattieVoice.shared.stop()
            pattie.react(.back)
        }
    }
}

/// The row both pickers use.
struct AskPattieOptionRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: TriSpace.x3) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TriPalette.inkSecondary)
                .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
                .background(TriPalette.inkSecondary.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: TriGeo.radiusInner, style: .continuous))

            VStack(alignment: .leading, spacing: TriSpace.x1) {
                Text(title)
                    .font(TriType.cardTitle)
                    .foregroundStyle(TriPalette.ink)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: TriSpace.x2)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TriPalette.inkTertiary)
        }
        .frame(minHeight: TriGeo.tapTarget + TriSpace.x4)
        .triCard()
        .contentShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
    }
}

/// One answer: her setup, her fix, her voice, and the episode it came from.
struct AskPattieAnswerCard: View {
    let answer: AskPattieGuide.Answer

    @ObservedObject private var voice = PattieVoice.shared
    @EnvironmentObject private var pattie: PattieMode
    @State private var catalog: PointerCatalog = .empty
    @State private var playingEpisode: Pointer?

    private var isSpeaking: Bool {
        voice.isPlaying(answer.solutionVoice) || voice.isPlaying(answer.situationVoice)
    }

    private var episode: Pointer? {
        guard let id = answer.pointerID else { return nil }
        return catalog.pointers.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TriSpace.x3) {
            Text(answer.headline)
                .font(TriType.cardTitle)
                .foregroundStyle(TriPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            block("Here's the situation", answer.situation, answer.situationVoice)
            block("Here's the solution", answer.solution, answer.solutionVoice)

            HStack(spacing: TriSpace.x2) {
                Button {
                    Haptics.tap()
                    voice.toggle(answer.solutionVoice ?? answer.situationVoice)
                } label: {
                    Label(isSpeaking ? "Stop" : "Hear it from Pattie",
                          systemImage: isSpeaking ? "stop.fill" : "play.fill")
                        .font(TriType.smallBold)
                        .foregroundStyle(TriPalette.inkOnDark)
                        .padding(.horizontal, TriSpace.x4)
                        .frame(minHeight: TriGeo.tapTarget)
                        .background(TriPalette.sunrise, in: Capsule())
                }
                .buttonStyle(.triPressSilent)

                if let episode {
                    Button {
                        Haptics.tap()
                        pattie.beginPointerPlayback()
                        playingEpisode = episode
                    } label: {
                        Label("Full clip", systemImage: "play.rectangle")
                            .font(TriType.smallBold)
                            .foregroundStyle(TriPalette.deep)
                            .padding(.horizontal, TriSpace.x4)
                            .frame(minHeight: TriGeo.tapTarget)
                            .overlay(Capsule().stroke(TriPalette.hairline, lineWidth: TriGeo.hairline))
                    }
                    .buttonStyle(.triPressSilent)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .triCard()
        .sheet(item: $playingEpisode) { PointerPlayerSheet(pointer: $0) }
        .task {
            guard catalog.pointers.isEmpty else { return }
            catalog = await PointerLibrary.shared.catalog()
        }
    }

    private func block(_ label: String, _ text: String, _ clip: String?) -> some View {
        VStack(alignment: .leading, spacing: TriSpace.x1) {
            HStack(spacing: TriSpace.x1) {
                Text(label.uppercased())
                    .font(TriType.micro)
                    .kerning(0.6)
                    .foregroundStyle(TriPalette.sunrise)
                if voice.isPlaying(clip) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TriPalette.sunrise)
                }
            }
            Text(text)
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
