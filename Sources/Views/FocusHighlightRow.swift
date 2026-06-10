#if os(tvOS)
	import SwiftUI

	/// A tvOS list/settings row whose focus appearance is a *contained* highlight
	/// rather than the system "lift".
	///
	/// The default tvOS focus effect scales the row up and draws a highlight that
	/// extends beyond the row's bounds, so it gets clipped by the enclosing scroll
	/// view's edges.  This row instead disables the system effect and renders its
	/// own highlight — dark content on a white capsule — entirely inside the row,
	/// so it is never truncated.  The look matches the focused toolbar button.
	///
	/// ```swift
	/// List {
	///     ForEach(items) { item in
	///         FocusHighlightRow { rowContent(item) }
	///     }
	/// }
	/// ```
	struct FocusHighlightRow<Content: View>: View {
		@FocusState private var isFocused: Bool
		private let action: () -> Void
		private let content: Content

		/// Creates a focusable row wrapping `content`.
		/// - Parameters:
		///   - action: Run when the row is selected. Defaults to no-op (a plain,
		///     non-actioning row).
		///   - content: The row's contents, shown dark when focused.
		init(
			action: @escaping () -> Void = {},
			@ViewBuilder content: () -> Content
		) {
			self.action = action
			self.content = content()
		}

		var body: some View {
			Button(action: action) {
				content
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.vertical, 10)
					.padding(.horizontal, 16)
					.foregroundStyle(isFocused ? Color.black : Color.primary)
					.background(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.fill(isFocused ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.clear))
					)
			}
			.buttonStyle(ContainedFocusButtonStyle())
			.focused($isFocused)
			.focusEffectDisabled()
			.animation(.easeInOut(duration: 0.12), value: isFocused)
		}
	}

	/// Renders only the label (with brief press dimming) so the system focus
	/// "lift" never appears; ``FocusHighlightRow`` supplies the highlight itself.
	private struct ContainedFocusButtonStyle: ButtonStyle {
		func makeBody(configuration: Configuration) -> some View {
			configuration.label
				.opacity(configuration.isPressed ? 0.6 : 1)
		}
	}
#endif
