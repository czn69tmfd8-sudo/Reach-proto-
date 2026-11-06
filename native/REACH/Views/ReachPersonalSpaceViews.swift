import SwiftUI
import PhotosUI

struct TogetherView: View {
    @EnvironmentObject private var appearance: ReachAppearanceStore
    var body: some View {
        ReachPage {
            Text("Together").font(.largeTitle.bold())
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Label("A moment for the two of you", systemImage: "sparkles").font(.title2.weight(.semibold))
                    Text("What’s one small moment you’d like to share today?")
                        .font(.title3).fixedSize(horizontal: false, vertical: true)
                    if appearance.preferences.showMessage && !appearance.preferences.personalMessage.isEmpty {
                        Text(appearance.preferences.personalMessage).font(.body).italic()
                    }
                    Text("Your optional message can be changed in Us. It stays on this iPhone.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                }
            }
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Room to grow").font(.headline)
                    Text("Shared memories, questions and date ideas will live here. They aren’t connected to a shared store yet.")
                        .font(.subheadline)
                }
            }
            NavigationLink {
                ReachHomeView()
            } label: {
                Label("Development demo · simulated connections", systemImage: "hammer")
                    .font(.footnote).padding(16)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
            Text("The demo never establishes a real call.").font(.caption)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ReachUsView: View {
    @EnvironmentObject private var appearance: ReachAppearanceStore
    @State private var selection: PhotosPickerItem?
    @State private var slot: ReachAppearanceStore.Photo = .own
    @State private var imageError: String?
    @State private var loading = false

    var body: some View {
        ReachPage {
            Text("Us").font(.largeTitle.bold())
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Make this space yours").font(.title2.weight(.semibold))
                    Text("Appearance settings stay on this iPhone. Names and photos don’t grant pairing access or change your partner’s profile.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                    TextField("Your display name", text: $appearance.preferences.ownName)
                        .accessibilityLabel("Your local display name")
                        .onChange(of: appearance.preferences.ownName) { _, text in
                            if text.count > 40 { appearance.preferences.ownName = String(text.prefix(40)) }
                        }
                    TextField("Partner’s display name", text: $appearance.preferences.partnerName)
                        .accessibilityLabel("Partner’s local display name")
                        .onChange(of: appearance.preferences.partnerName) { _, text in
                            if text.count > 40 { appearance.preferences.partnerName = String(text.prefix(40)) }
                        }
                    Toggle("Show a personal message in Together", isOn: $appearance.preferences.showMessage)
                    TextField("Your optional words", text: $appearance.preferences.personalMessage, axis: .vertical)
                        .lineLimit(3...6).accessibilityLabel("Optional personal message")
                        .onChange(of: appearance.preferences.personalMessage) { _, text in
                            if text.count > 600 { appearance.preferences.personalMessage = String(text.prefix(600)) }
                        }
                }
                .textFieldStyle(.roundedBorder)
            }
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your photographs").font(.headline)
                    Picker("Photo to change", selection: $slot) {
                        ForEach(ReachAppearanceStore.Photo.allCases) { value in Text(value.label).tag(value) }
                    }.pickerStyle(.menu).disabled(loading)
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label(loading ? "Loading photograph…" : "Choose photograph", systemImage: "photo")
                            .frame(minHeight: 44)
                    }.disabled(loading)
                    if appearance.image(for: slot) != nil {
                        Button(slot == .background ? "Restore original sunset" : "Remove this local photo", role: .destructive) {
                            do { try appearance.setPhoto(nil, for: slot) } catch { imageError = error.localizedDescription }
                        }.frame(minHeight: 44).disabled(loading)
                    }
                    Text("Only a photo you select is imported. Photos are stored privately on this device and aren’t uploaded or shared.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                    if let imageError { Text(imageError).font(.footnote) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: slot) { _, _ in selection = nil; imageError = nil }
        .task(id: selection) {
            guard let selection else { return }
            let selectedSlot = slot
            loading = true; imageError = nil
            defer { loading = false; self.selection = nil }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    throw ReachAppearanceStore.AppearanceError.image
                }
                try Task.checkCancellation()
                try appearance.setPhoto(data, for: selectedSlot)
            } catch is CancellationError { return }
            catch { imageError = error.localizedDescription }
        }
    }
}
