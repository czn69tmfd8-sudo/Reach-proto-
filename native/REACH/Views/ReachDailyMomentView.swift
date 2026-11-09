import SwiftUI

/// Local, read-only daily encouragement. No Firebase, call state, or pairing access.
enum ReachDailyMoments {
    // 70 love/relationship messages and 30 general encouragement messages.
    static let messages: [String] = [
        "Love is found in the little moments we choose to share.",
        "The little check-ins are part of a big love.",
        "Choose patience when life asks you to wait.",
        "A thoughtful pause can be an act of love.",
        "Love can be steady even when the day is busy.",
        "A little courage goes a long way.",
        "Sometimes the most beautiful plan is simply being together.",
        "A little encouragement can help your partner feel seen.",
        "Your attention is a gift; spend it wisely.",
        "The strongest bonds are cared for in ordinary moments.",
        "Gratitude makes ordinary moments feel extraordinary.",
        "Distance changes where we are, not how deeply we can care.",
        "Choose curiosity over assumptions.",
        "Choose what matters over what is loudest.",
        "Love grows when two people feel free to be themselves.",
        "Love can feel like peace at the end of a long day.",
        "Take pride in the promises you keep to yourself.",
        "Choose tenderness when words feel difficult.",
        "The best love leaves room for joy and rest.",
        "Love makes room for both closeness and breathing space.",
        "Love is not measured by the miles between you.",
        "Small progress is still progress.",
        "There is tenderness in simply making time for each other.",
        "Leave room for each other to grow.",
        "Speak to yourself with the kindness you offer others.",
        "Love listens before it answers.",
        "Trust grows through small promises kept.",
        "Tomorrow benefits from the kindness you practice today.",
        "Make room for laughter in the middle of hard weeks.",
        "Celebrate the ordinary days; they are part of your story.",
        "Kindness matters most in the moments that aren't easy.",
        "A shared dream begins with an honest conversation.",
        "You can grow without rushing.",
        "You don't have to share every moment to feel connected.",
        "Good relationships welcome honest feelings.",
        "Celebrate progress without comparing paths.",
        "A warm hello can turn an ordinary day around.",
        "Love is choosing care again tomorrow.",
        "The best conversations begin with genuine curiosity.",
        "Being understood is a beautiful kind of closeness.",
        "Your next step does not need to be perfect.",
        "Small acts of care create lasting memories.",
        "You do not need a special occasion to show appreciation.",
        "Joy can be found in simple routines.",
        "Affection thrives when it is given freely.",
        "Affection is a language of thoughtful details.",
        "A little kindness can travel any distance.",
        "A gentle question can open a meaningful conversation.",
        "Today is another chance to begin well.",
        "Listening is love made visible.",
        "A meaningful connection is built one choice at a time.",
        "A fresh start can happen at any hour.",
        "You can miss someone and still give them room to grow.",
        "Make memories out of ordinary evenings.",
        "Keep a little space for wonder.",
        "Celebrate the courage it takes to be vulnerable.",
        "The little things are often the big things in disguise.",
        "An open hand is an invitation, never an expectation.",
        "There is strength in repairing after a disagreement.",
        "Let today hold one good surprise.",
        "Be grateful for the person, not just the time you get together.",
        "A sincere apology is an act of care.",
        "One thoughtful choice can change your day.",
        "Every honest conversation builds a little more trust.",
        "Build a home in the way you treat each other.",
        "Sometimes love sounds like: I'm here whenever you're ready.",
        "Patience gives affection room to breathe.",
        "Rest is part of moving forward.",
        "Connection is a choice we can make again and again.",
        "A loving partnership makes space for both voices.",
        "Make time for what restores you.",
        "Two hearts can feel close across many miles.",
        "A moment of attention can mean everything.",
        "Being present is one of the simplest ways to say I love you.",
        "Respect is one of love's quietest gifts.",
        "A gentle word can change the direction of a difficult day.",
        "Love is strengthened by honesty spoken with care.",
        "A kind word travels farther than you think.",
        "Notice something beautiful in the ordinary.",
        "The way we treat each other in small moments shapes our story.",
        "Love is stronger when kindness is consistent.",
        "Hope grows when you make room for it.",
        "Love is a practice, not a perfect performance.",
        "Make space for joy, even on busy days.",
        "A shared laugh can make the miles feel smaller.",
        "Let your partner feel heard, not hurried.",
        "A calm breath can make room for a clearer thought.",
        "A caring heart can turn an ordinary evening into a memory.",
        "Remember the reasons you choose each other.",
        "You are allowed to learn as you go.",
        "Love makes room for a partner's whole story.",
        "A simple thank you can deepen connection.",
        "The most meaningful gift is often your undivided attention.",
        "You can be independent and deeply connected.",
        "Give yourself credit for showing up.",
        "Let appreciation be something you say, not only something you feel.",
        "Sometimes the smallest gesture says the most.",
        "The effort you make today matters.",
        "A thoughtful good morning can brighten the longest day.",
        "Let warmth guide the way you speak."
    ]

    /// UTC date keeps the daily selection consistent across partner time zones.
    static func index(for date: Date) -> Int {
        let day = Int(floor(date.timeIntervalSince1970 / 86_400))
        return ((day % messages.count) + messages.count) % messages.count
    }

    static func message(for date: Date) -> String {
        messages[index(for: date)]
    }
}

struct ReachDailyMomentView: View {
    @AppStorage("reach.dailyMoments.enabled") private var enabled = true
    @AppStorage("reach.dailyMoments.savedIndices") private var savedIndices = ""
    @State private var showSaved = false
    let now: Date

    private var index: Int { ReachDailyMoments.index(for: now) }
    private var quote: String { ReachDailyMoments.message(for: now) }
    private var saved: Set<Int> {
        Set(savedIndices.split(separator: ",").compactMap { Int($0) }
            .filter { (0..<ReachDailyMoments.messages.count).contains($0) })
    }
    private var isSaved: Bool { saved.contains(index) }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("A little love, daily")
                        .font(.headline.weight(.semibold))
                    Text("A moment to carry with you")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 4)
                Toggle("Daily reminders", isOn: $enabled)
                    .labelsHidden()
                    .tint(.pink)
                    .accessibilityLabel("Show daily reminder")
            }

            if enabled {
                VStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.pink.opacity(0.9))
                        .accessibilityHidden(true)
                    Text("“\\(quote)”")
                        .font(.system(.body, design: .serif).weight(.medium))
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Today's reminder: \\(quote)")
                    Text("TODAY'S THOUGHT")
                        .font(.caption2.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 19)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.14)))

                HStack(spacing: 12) {
                    Button {
                        var next = saved
                        if isSaved { next.remove(index) } else { next.insert(index) }
                        savedIndices = next.sorted().map(String.init).joined(separator: ",")
                    } label: {
                        Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "heart.fill" : "heart")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                    .accessibilityLabel(isSaved ? "Remove reminder from saved" : "Save today's reminder")

                    ShareLink(item: "A little reminder from REACH ❤️\\n\\n“\\(quote)”\\n\\nThinking of you.") {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)

                if !saved.isEmpty {
                    DisclosureGroup("Saved reminders (\\(saved.count))", isExpanded: $showSaved) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(saved.sorted(), id: \\.self) { savedIndex in
                                Text("“\\(ReachDailyMoments.messages[savedIndex])”")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(17)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.16, green: 0.09, blue: 0.27).opacity(0.78))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(
            LinearGradient(colors: [.pink.opacity(0.75), .purple.opacity(0.35), .white.opacity(0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}
