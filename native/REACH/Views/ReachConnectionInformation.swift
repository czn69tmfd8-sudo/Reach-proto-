import SwiftUI
import UIKit

struct ReachConnectionInformation: View {
    let page: String
    @ObservedObject var call: StagingCallController
    @Environment(\.openURL) private var openURL
    var body: some View {
        ReachGlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                switch page {
                case "privacy":
                    Text("Your space, your choice").font(.title2.bold())
                    Text("Together entries, milestones, display names and selected photographs stay on this iPhone. They are not synchronized with your partner. Deleting the app removes this local content.")
                    Text("Pairing and call signaling use the isolated REACH staging project. Camera and microphone begin only after an explicit open or take action. No call recording feature is included.")
                case "security":
                    Text("Consent comes first").font(.title2.bold())
                    Text("A pairing code is an invitation, not a call. Both members must choose to connect. End, backgrounding the app and navigating away stop local media. Revocation ends that pair’s call authorization. Pairing again requires a fresh invitation.")
                    Text("Native staging data is separate from the web app. Local names and photos never grant access. Access can fail closed when the network or authorization cannot be verified.")
                case "about":
                    Text("REACH").font(.largeTitle.bold())
                    Text("Same moment. Any distance.")
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                    Text("Private staging · not a public service release. The original sunset remains the default background. Your own photographs and words are optional.")
                default:
                    Text("Real connection, explicit invitation").font(.title2.bold())
                    Text("Keep REACH open in the foreground. A paired heart does not indicate online presence or a working audio/video connection. Only the media transport reports a connected call.")
                    Text("Direct/STUN connectivity may fail on restrictive networks. TURN relay service is not configured. A failed connection never silently restarts or rejoins a call.")
                    Text("If camera or microphone access was denied, enable it in iPhone Settings, then return and explicitly try again.")
                    Button("Open iPhone app settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }.buttonStyle(.bordered).frame(minHeight: 44)
                    DisclosureGroup("Call troubleshooting") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(call.phase.title ?? "No active call")
                                .font(.subheadline.weight(.semibold))
                            if call.diagnostics.events.isEmpty { Text("No call events yet.") }
                            ForEach(call.diagnostics.events) { sample in
                                LabeledContent(sample.event.rawValue) {
                                    Text(sample.date, style: .time)
                                }
                            }
                            Text("Only the latest 20 event labels and times are kept in memory. No identifiers, signaling payloads, audio or video are included.")
                                .font(.footnote)
                        }
                        .padding(.top, 10)
                    }
                }
            }
        }
    }
}
