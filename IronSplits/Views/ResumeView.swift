import SwiftUI

/// The main Race Book destination. The old Resume and Bests surfaces now live
/// together here, so the career story, personal bests and export builder are in
/// one place.
struct ResumeView: View {
    @EnvironmentObject private var pattie: PattieMode

    var body: some View {
        NavigationStack {
            RaceBookView()
                .pattieMoment(.resume, pattie)
        }
    }
}
