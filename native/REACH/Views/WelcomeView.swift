import SwiftUI

struct WelcomeView: View {
    let continueAction: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo, .purple, .pink.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 76))
                Text("REACH")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                Text("Reach for each other, same moment, any distance.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                Button("Begin") { continueAction() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.white.opacity(0.22))

                Text("Connection is always intentional. You choose when your hand is open.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .foregroundStyle(.white)
            .padding(28)
        }
    }
}
