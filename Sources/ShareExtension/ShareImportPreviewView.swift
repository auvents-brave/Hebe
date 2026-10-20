import SwiftUI

struct ShareImportPreviewView: View {
	@ObservedObject var viewModel: ShareImportViewModel

	var body: some View {
		VStack(spacing: 0) {
			content
				.frame(maxWidth: .infinity, maxHeight: .infinity)

			Divider()

			actionBar
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
				.background(.ultraThinMaterial)
		}
		.background(platformBackgroundColor)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
		case .loading:
			VStack(spacing: 12) {
				ProgressView()
				Text("Loading shared content...")
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.padding(24)
		case .ready(let digests):
			VStack(alignment: .leading, spacing: 12) {
				Text("Import Preview")
					.font(.headline)
					.padding(.horizontal, 16)
					.padding(.top, 16)

				FurnitureTreeListView(digests: digests)
			}
		case .empty:
			emptyState
		case .failed(let message):
			VStack(spacing: 16) {
				ContentUnavailableView("Nothing to import", systemImage: "tray")
				Text(message)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 24)
				schemaReminder
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.padding(24)
		}
	}

	private var emptyState: some View {
		VStack(spacing: 16) {
			ContentUnavailableView("Nothing to import", systemImage: "tray")
			schemaReminder
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(24)
	}

	private var schemaReminder: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Expected XML")
				.font(.headline)
			Text(ShareImportSchema.exampleXML)
				.font(.system(.footnote, design: .monospaced))
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(12)
				.background(Color.secondary.opacity(0.08))
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		}
		.frame(maxWidth: 480, alignment: .leading)
	}

	@ViewBuilder
	private var actionBar: some View {
		switch viewModel.state {
		case .ready:
			HStack(spacing: 12) {
				Button("Cancel") {
					viewModel.cancel()
				}
				.buttonStyle(.bordered)

				Spacer()

				Button(viewModel.isImporting ? "Importing..." : "Import") {
					viewModel.importContent()
				}
				.buttonStyle(.borderedProminent)
				.disabled(viewModel.isImporting)
			}
		default:
			HStack {
				Spacer()
				Button("Cancel") {
					viewModel.cancel()
				}
				.buttonStyle(.bordered)
			}
		}
	}

	private var platformBackgroundColor: Color {
		#if os(macOS)
			Color(nsColor: .windowBackgroundColor)
		#else
			Color(uiColor: .systemBackground)
		#endif
	}
}
