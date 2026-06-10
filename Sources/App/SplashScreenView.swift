import SwiftUI

struct SplashScreenView: View {
	@State private var isSpinning = false

	var body: some View {
		ZStack {
			Color(.launchBackground)
				.ignoresSafeArea()

			VStack(spacing: 16) {
				Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
					.font(.system(size: 72, weight: .semibold))
					.foregroundStyle(.white)
					.rotationEffect(.degrees(isSpinning ? 360 : 0))
					.animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSpinning)

				Text(String(localized: "Initializing..."))
					.font(.headline)
					.foregroundStyle(.white)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.task { isSpinning = true }
		.accessibilityIdentifier("splash_screen")
	}
}

#Preview("Splash Screen") {
	SplashScreenView()
}
