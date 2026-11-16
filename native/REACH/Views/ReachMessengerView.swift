import SwiftUI

struct ReachMessengerView: View {
    @EnvironmentObject private var appearance: ReachAppearanceStore
    @Environment(\.scenePhase) private var scene
    @StateObject private var store = MessengerStore()
    @State private var draft = ""
    @State private var reload = 0

    var body: some View {
        VStack(spacing: 8) {
            if !store.notice.isEmpty {
                Text(store.notice)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if store.ownUID == nil {
                    Button("Reconnect") { reload += 1 }
                        .buttonStyle(.bordered)
                }
            }
            if !store.unread.isEmpty {
                Button {
                    Task { await store.markRead() }
                } label: {
                    Label("Mark as read", systemImage: "envelope.badge")
                }
                .buttonStyle(.bordered)
                .disabled(!store.online)
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.hasMore {
                        Button("Load earlier messages") { Task { await store.loadMore() } }
                            .buttonStyle(.bordered)
                            .disabled(store.loadingMore || !store.online)
                    }
                    if store.ownUID != nil && store.messages.isEmpty && store.pendingText == nil {
                        Text("Send your first message to \(appearance.preferences.partnerLabel).")
                            .font(.subheadline)
                    }
                    ForEach(store.messages) { message in
                        bubble(message)
                    }
                    if let pending = store.pendingText {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(pending).multilineTextAlignment(.trailing)
                            if store.retryAvailable {
                                Button("Retry") { Task { await store.sendPending() } }.disabled(!store.online)
                            } else {
                                Text(store.online ? "Sending…" : "Waiting to send").font(.caption)
                            }
                        }
                        .padding(10)
                        .background(.pink.opacity(0.32), in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)

            if store.ownUID != nil {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Message", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    Button {
                        let text = trimmedDraft
                        draft = ""
                        Task { await store.send(text) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Send message")
                    .disabled(trimmedDraft.isEmpty || trimmedDraft.utf8.count > 4000 || store.pendingText != nil)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                if trimmedDraft.utf8.count > 4000 {
                    Text("This message is too long.").font(.footnote)
                }
            }
        }
        .foregroundStyle(.white)
        .background { ReachHomeBackground(source: appearance.background) }
        .navigationTitle("Our Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(.pink)
        .environment(\.colorScheme, .dark)
        .task(id: "\(scene)-\(reload)") {
            if scene == .active { await store.watch() }
            else { clear() }
        }
        .onDisappear { clear() }
        .onChange(of: store.ownUID) { _, value in if value == nil { draft = "" } }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clear() {
        draft = ""
        store.stop()
    }

    private func bubble(_ message: MessengerStore.Message) -> some View {
        let own = message.sender == store.ownUID
        return VStack(alignment: own ? .trailing : .leading, spacing: 4) {
            Text(message.text)
                .textSelection(.enabled)
            HStack(spacing: 6) {
                Text(message.timestamp.dateValue().formatted(date: .abbreviated, time: .shortened))
                if store.unread.contains(message.id) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.pink)
                        .accessibilityLabel("Unread")
                }
            }
            .font(.caption2)
        }
        .padding(10)
        .background(own ? .pink.opacity(0.38) : .black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: own ? .trailing : .leading)
    }
}
