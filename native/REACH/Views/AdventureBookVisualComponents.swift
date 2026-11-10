import SwiftUI

/// Presentation-only surfaces; no Firebase or pairing dependencies.
enum AdventureBookPalette {
    static let ink = Color(red: 0.29, green: 0.17, blue: 0.12)
    static let paper = Color(red: 0.96, green: 0.89, blue: 0.74)
    static let parchmentLight = Color(red: 1.0, green: 0.96, blue: 0.84)
    static let leather = Color(red: 0.30, green: 0.14, blue: 0.09)
    static let gold = Color(red: 0.82, green: 0.65, blue: 0.35)
}


/// A deterministic leather-grain impression with no downloaded artwork.
private struct AdventureLeatherGrain: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let step: CGFloat = 9
            for column in 0..<Int(size.width / step) {
                for row in 0..<Int(size.height / step) {
                    let seed = (column * 73 + row * 139) % 19
                    let x = CGFloat(column) * step + CGFloat(seed % 5)
                    let y = CGFloat(row) * step + CGFloat(seed % 7)
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 2.4)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.055)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct AdventureLeatherCover: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            ZStack {
                RoundedRectangle(cornerRadius: 19)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.45, green: 0.24, blue: 0.14),
                        AdventureBookPalette.leather,
                        Color(red: 0.19, green: 0.09, blue: 0.07)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                // Fine-grain leather and stitched border are vector-drawn,
                // requiring no external image asset or new permissions.
                AdventureLeatherGrain()
                    .clipShape(RoundedRectangle(cornerRadius: 19))
                    .accessibilityHidden(true)
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(AdventureBookPalette.gold.opacity(0.7), lineWidth: 1.5)
                    .padding(12)
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(AdventureBookPalette.gold.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .padding(16)
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(AdventureBookPalette.gold.opacity(0.35),
                                  style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    .padding(19)
                HStack {
                    Rectangle().fill(.black.opacity(0.25)).frame(width: 11)
                    Rectangle().fill(AdventureBookPalette.gold.opacity(0.2)).frame(width: 2)
                    Spacer()
                }
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [
                            Color(red: 0.22, green: 0.11, blue: 0.08),
                            Color(red: 0.53, green: 0.29, blue: 0.17)
                        ], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 52, height: 48)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(AdventureBookPalette.gold.opacity(0.8), lineWidth: 1.5)
                        }
                        .overlay {
                            Image(systemName: "circle.circle")
                                .foregroundStyle(AdventureBookPalette.gold)
                        }
                        .offset(x: 12, y: 18)
                }
                VStack(spacing: 21) {
                    Spacer()
                    Image(systemName: "safari")
                        .font(.system(size: 42, weight: .ultraLight))
                        .accessibilityHidden(true)
                    Text("OUR ADVENTURE\nBOOK")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .tracking(2.2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.72)
                    HStack(spacing: 12) {
                        Rectangle().frame(width: 36, height: 1)
                        Image(systemName: "heart.fill").font(.system(size: 13))
                        Rectangle().frame(width: 36, height: 1)
                    }
                    Text("Two hearts · One unfolding story")
                        .font(.system(size: 15, design: .serif)).italic()
                    Spacer()
                    Image(systemName: "safari")
                        .font(.system(size: 46, weight: .ultraLight))
                        .rotationEffect(.degrees(20))
                        .opacity(0.55)
                        .accessibilityHidden(true)
                    Label("Touch to open", systemImage: "book.pages")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 34)
                .foregroundStyle(AdventureBookPalette.gold)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 2)
            }
            .shadow(color: .black.opacity(0.3), radius: 14, x: 5, y: 8)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Our Adventure Book")
        .accessibilityHint("Opens the shared memories gallery")
    }
}

struct AdventureParchmentPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 19)
                .padding(.vertical, 24)
        }
        .foregroundStyle(AdventureBookPalette.ink)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [
                    AdventureBookPalette.parchmentLight,
                    AdventureBookPalette.paper,
                    Color(red: 0.91, green: 0.82, blue: 0.66)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AdventureBookPalette.ink.opacity(0.16), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.18), radius: 8, x: 3, y: 5)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
    }
}

struct AdventureStoryCard: View {
    let heading: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(heading)
                .font(.system(size: 19, weight: .medium, design: .serif))
                .italic()
            Rectangle().fill(AdventureBookPalette.gold.opacity(0.7))
                .frame(width: 72, height: 1)
            Text(text.isEmpty ? "A story waiting to be written…" : text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(AdventureBookPalette.ink.opacity(text.isEmpty ? 0.55 : 1))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(AdventureBookPalette.ink.opacity(0.12)))
    }
}
