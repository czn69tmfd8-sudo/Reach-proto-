#if DEBUG && targetEnvironment(simulator)
import SwiftUI

enum CallSimulatorPreview: String {
    case controls, hidden

    static var requested: Self? {
        let prefix = "--call-simulator-preview="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return Self(rawValue: String(argument.dropFirst(prefix.count)))
    }
}

private struct CallSimulatorPreviewKey: EnvironmentKey {
    static let defaultValue: CallSimulatorPreview? = nil
}

extension EnvironmentValues {
    var callSimulatorPreview: CallSimulatorPreview? {
        get { self[CallSimulatorPreviewKey.self] }
        set { self[CallSimulatorPreviewKey.self] = newValue }
    }
}

struct CallSimulatorPreviewShell: View {
    let preview: CallSimulatorPreview
    @StateObject private var call = StagingCallController()
    @State private var stopID = UUID()

    var body: some View {
        VStack {
            Text("REACH")
                .font(.title)
            StagingCallView(call: call, stopID: stopID, availability: .unavailable,
                            roomID: nil, now: .now, pairingBusy: false) { _ in }
        }
        .environment(\.callSimulatorPreview, preview)
        .task { call.connectSimulatorPreview() }
    }
}

struct SimulatorVideoPattern: View {
    let title: String
    let detail: String?

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Color(red: 0.14, green: 0.24, blue: 0.31)
                Color(red: 0.19, green: 0.34, blue: 0.40)
                Color(red: 0.27, green: 0.42, blue: 0.43)
                Color(red: 0.43, green: 0.41, blue: 0.34)
            }
            VStack(spacing: 6) {
                Text(title).font(.headline)
                if let detail { Text(detail).font(.caption2.monospaced()) }
            }
            .padding(8)
            .background(.black.opacity(0.6), in: .rect(cornerRadius: 8))
        }
        .foregroundStyle(.white)
    }
}
#endif
