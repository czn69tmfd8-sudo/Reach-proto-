import SwiftUI
import PhotosUI

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
                .submitLabel(.done).onSubmit { ReachKeyboard.dismiss() }
            }
            RelationshipMilestonesView()
            ReachGlassPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your photographs").font(.headline)
                    Picker("Photo to change", selection: $slot) {
                        ForEach(ReachAppearanceStore.Photo.allCases) { value in Text(value.label).tag(value) }
                    }.pickerStyle(.menu).disabled(loading)
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label("Choose photograph", systemImage: "photo")
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
