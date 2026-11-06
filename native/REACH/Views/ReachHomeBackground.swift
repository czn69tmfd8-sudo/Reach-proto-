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

/// Real profile images can be supplied later; absent photos stay visibly empty.
/// This component never reads the web profile or implies an authorized pairing.
struct ReachHomeIdentityHeader: View {
    var localPhoto: UIImage? = nil
    var partnerPhoto: UIImage? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text("REACH")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [.pink, Color(red: 0.94, green: 0.64, blue: 0.91), .cyan],
                    startPoint: .leading, endPoint: .trailing
                ))
            Text("Reach for each other, same moment, any distance.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            HStack(spacing: 28) {
                portrait(localPhoto, label: "You")
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                    .accessibilityHidden(true)
                portrait(partnerPhoto, label: "Your partner")
            }
            Text("REACH STAGING")
                .font(.caption2.weight(.semibold))
                .tracking(2)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private func portrait(_ photo: UIImage?, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 40, weight: .light))
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5))
            .accessibilityLabel(photo == nil ? "\(label): profile photo not set" : "\(label): profile photo")
            Text(label).font(.caption.weight(.semibold))
        }
    }
}
