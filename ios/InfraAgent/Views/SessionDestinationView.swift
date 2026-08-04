import SwiftUI

struct SessionDestinationView: View {
    let session: BaseSession

    var body: some View {
        switch session.payload {
        case .techRadar(let payload):
            TechRadarView(session: session, payload: payload)
        case .jdAnalysis:
            JDIntelligenceView()
        case .researchFeeder(let payload):
            ResearchReaderView(session: session, payload: payload)
        }
    }
}
