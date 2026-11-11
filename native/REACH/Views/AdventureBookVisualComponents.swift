import SwiftUI
import UIKit

/// Presentation only. Bundled artwork has no relationship to saved/private photos.
enum AdventureBookPalette {
    static let ink = Color(red: 0.28, green: 0.16, blue: 0.10)
    static let paper = Color(red: 0.95, green: 0.85, blue: 0.66)
    static let parchmentLight = Color(red: 0.99, green: 0.93, blue: 0.80)
    static let leather = Color(red: 0.30, green: 0.14, blue: 0.09)
    static let gold = Color(red: 0.91, green: 0.74, blue: 0.43)
    static let burgundy = Color(red: 0.43, green: 0.13, blue: 0.14)
    static func script(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("SnellRoundhand", size: size, relativeTo: style)
    }
    static func handwriting(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Noteworthy-Light", size: size, relativeTo: style)
    }
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Baskerville", size: size, relativeTo: style)
    }
}

/// Six atlas regions. Original artwork, never downloaded from a partner's account.
@MainActor
enum AdventureArtwork {
    static let regions: [UIImage] = {
        guard let atlas = UIImage(named: "AdventureMaterials")?.cgImage else { return [] }
        let width = CGFloat(atlas.width) / 3
        let height = CGFloat(atlas.height)
        let rects = [CGRect(x: 0, y: 0, width: width, height: height),
                     CGRect(x: width, y: 0, width: width, height: height),
                     CGRect(x: width * 2, y: 0, width: width / 2, height: height / 2),
                     CGRect(x: width * 2.5, y: 0, width: width / 2, height: height / 2),
                     CGRect(x: width * 2, y: height / 2, width: width / 2, height: height / 2),
                     CGRect(x: width * 2.5, y: height / 2, width: width / 2, height: height / 2)]
        return rects.compactMap { atlas.cropping(to: $0).map { UIImage(cgImage: $0) } }
    }()
    static func image(_ region: Int) -> Image {
        guard regions.indices.contains(region) else { return Image(systemName: "book.closed") }
        return Image(uiImage: regions[region])
    }
}

struct AdventureLeatherArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                AdventureArtwork.image(0).resizable()
                VStack(spacing: 0) {
                    Text("Our\nAdventure\nBook")
                        .font(AdventureBookPalette.script(width * 0.115))
                        .lineSpacing(-width * 0.018)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AdventureBookPalette.gold)
                        .shadow(color: .black.opacity(0.9), radius: 1, x: 0, y: 2)
                        .padding(.top, width * 0.08)
                    Spacer(minLength: 0)
                }
                HStack(spacing: -width * 0.11) {
                    AdventureMountedPhoto(sample: 0, title: nil)
                        .frame(width: width * 0.31, height: width * 0.29)
                        .rotationEffect(.degrees(-13))
                    AdventureMountedPhoto(sample: 3, title: nil)
                        .frame(width: width * 0.26, height: width * 0.24)
                        .rotationEffect(.degrees(8)).offset(y: width * 0.07)
                    Spacer()
                }
                .padding(.leading, width * 0.10)
                .offset(y: geometry.size.height * 0.29)
            }
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: .black.opacity(0.5), radius: 8, x: 3, y: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aged leather Adventure Book with stitching, brass clasp, embossed compass and decorative travel prints")
    }
}

struct AdventureLeatherCover: View {
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(spacing: 10) {
                AdventureLeatherArtwork().aspectRatio(0.91, contentMode: .fit)
                Text("Touch to open").font(AdventureBookPalette.serif(15)).foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Our Adventure Book")
        .accessibilityHint("Opens the memories gallery. Cover prints are decorative examples.")
    }
}

struct AdventurePaperSurface: View {
    var body: some View {
        AdventureArtwork.image(1).resizable()
            .accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct AdventureParchmentPage<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            content.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(AdventureBookPalette.ink)
        .background { AdventurePaperSurface() }
        .shadow(color: .black.opacity(0.36), radius: 8, x: 2, y: 5)
        .padding(.horizontal, 6).padding(.vertical, 6)
        .environment(\.colorScheme, .light)
    }
}

struct AdventureTape: View {
    var body: some View {
        Rectangle().fill(Color(red: 0.76, green: 0.64, blue: 0.43).opacity(0.66))
            .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
            .frame(width: 36, height: 13)
            .accessibilityHidden(true)
    }
}

struct AdventureMountedFrame<Content: View>: View {
    var title: String?
    @ViewBuilder let photo: Content
    var body: some View {
        VStack(spacing: 3) {
            photo.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            if let title {
                Text(title).font(AdventureBookPalette.handwriting(16, relativeTo: .caption))
                    .foregroundStyle(AdventureBookPalette.ink).lineLimit(2)
            }
        }
        .padding(7).padding(.bottom, title == nil ? 8 : 3)
        .background(AdventureBookPalette.parchmentLight)
        .overlay(alignment: .topLeading) { AdventureTape().rotationEffect(.degrees(-38)).offset(x: -7, y: 3) }
        .overlay(alignment: .bottomTrailing) { AdventureTape().rotationEffect(.degrees(-38)).offset(x: 6, y: -3) }
        .shadow(color: .black.opacity(0.28), radius: 3, x: 1, y: 3)
    }
}

struct AdventureMountedPhoto: View {
    let sample: Int
    var title: String?
    var body: some View {
        AdventureMountedFrame(title: title) {
            GeometryReader { geometry in
                AdventureArtwork.image(2 + sample % 4).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
        }
        .accessibilityLabel(title.map { "Sample illustration: \($0)" } ?? "Decorative sample travel print")
    }
}

struct AdventureStoryCard: View {
    let heading: String
    let text: String
    var tint = Color(red: 0.69, green: 0.33, blue: 0.27)
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(heading).font(AdventureBookPalette.script(22, relativeTo: .headline))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.18))
            Text(text.isEmpty ? "A story waiting to be written…" : text)
                .font(AdventureBookPalette.handwriting(15))
                .foregroundStyle(AdventureBookPalette.ink.opacity(text.isEmpty ? 0.65 : 1))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9).padding(.bottom, 10)
        }
        .foregroundStyle(AdventureBookPalette.ink)
        .background(AdventureBookPalette.parchmentLight.opacity(0.65))
        .overlay(Rectangle().stroke(AdventureBookPalette.ink.opacity(0.14)))
        .shadow(color: .brown.opacity(0.18), radius: 2, x: 1, y: 2)
        .accessibilityElement(children: .combine)
    }
}

struct AdventureGalleryHeading: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill").foregroundStyle(.olive)
            Text("Our shared memories, two perspectives\nand the story we’re writing together.")
                .font(AdventureBookPalette.serif(17)).italic()
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            Image(systemName: "heart").foregroundStyle(AdventureBookPalette.burgundy)
        }
        .padding(.bottom, 8)
    }
}

private extension Color {
    static let olive = Color(red: 0.36, green: 0.40, blue: 0.21)
}

struct AdventureBookHeader: View {
    let title: String
    let back: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Button(action: back) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Back")
            Text(title).font(AdventureBookPalette.script(25)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white).padding(.horizontal, 4)
    }
}
