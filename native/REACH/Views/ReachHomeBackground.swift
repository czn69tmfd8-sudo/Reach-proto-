import SwiftUI
import UIKit

/// Presentation only. A future photo picker can supply a couple-owned image
/// without changing the default artwork, call state, or pairing authorization.
enum ReachHomeBackgroundSource {
    case originalSunset
    case couplePhoto(UIImage)
}

struct ReachHomeBackground: View {
    var source: ReachHomeBackgroundSource = .originalSunset

    private var photograph: Image {
        switch source {
        case .originalSunset: return Image("OriginalSunset")
        case .couplePhoto(let image): return Image(uiImage: image)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            photograph
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                // Readability treatment is a separate layer; original pixels stay intact.
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.38), .clear, .black.opacity(0.48)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// The heart is an ambient pairing cue, never proof of a live media connection.
struct ReachConnectionHeart: View {
    var active = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 46, weight: .light))
            .foregroundStyle(LinearGradient(colors: [.pink, .purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            .symbolEffect(.pulse, options: .repeating, isActive: active && !reduceMotion && scenePhase == .active)
            .shadow(color: .pink.opacity(0.45), radius: 15)
            .frame(width: 56, height: 78)
            .accessibilityHidden(true)
    }
}

struct ReachHomeIdentityHeader: View {
    @EnvironmentObject private var appearance: ReachAppearanceStore
    var paired = false
    @ScaledMetric(relativeTo: .title) private var photoSize: CGFloat = 107

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                portrait(appearance.ownPhoto, label: appearance.preferences.ownLabel, tint: .pink)
                ReachConnectionHeart(active: paired)
                portrait(appearance.partnerPhoto, label: appearance.preferences.partnerLabel, tint: .purple)
            }
            .frame(maxWidth: .infinity)
            if paired {
                Label("Pairing verified", systemImage: "checkmark.circle")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.54), in: Capsule())
            }
        }
        .foregroundStyle(.white)
    }

    private func portrait(_ photo: UIImage?, label: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 42, weight: .ultraLight))
                }
            }
            .frame(width: min(photoSize, 107), height: min(photoSize, 107))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(tint.opacity(0.9), lineWidth: 2))
            .shadow(color: tint.opacity(0.35), radius: 12)
            .accessibilityLabel(photo == nil ? "\(label): profile photo not set" : "\(label): local profile photo")
            Text(label).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                .frame(width: min(photoSize, 107))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ReachGlassPanel<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial).opacity(reduceTransparency ? 1 : 0.45)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(red: 0.14, green: 0.06, blue: 0.23).opacity(reduceTransparency ? 1 : 0.38))
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.pink.opacity(0.48), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
            .foregroundStyle(.white)
    }
}

struct ReachPage<Content: View>: View {
    @EnvironmentObject private var appearance: ReachAppearanceStore
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(spacing: 20) { content }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
        }
        .background { ReachHomeBackground(source: appearance.background) }
        .scrollDismissesKeyboard(.interactively)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(red: 0.12, green: 0.07, blue: 0.19), for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .reachKeyboardToolbar()
        .foregroundStyle(.white)
        .tint(.pink)
        .environment(\.colorScheme, .dark)
    }
}
