import SwiftUI

/// Address search and the "use my location" button, floating over the map.
struct SearchPanel: View {
    @Bindable var store: PharmacyStore
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField(String(localized: "Address or place"), text: $store.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit { submit() }
                    .accessibilityLabel(String(localized: "Address or place"))

                if !store.query.isEmpty {
                    Button {
                        store.query = ""
                        isFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Clear the search"))
                }

                if store.phase == .searching {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                isFocused = false
                Task { await store.useCurrentLocation() }
            } label: {
                Image(systemName: store.isLocating ? "location.fill" : "location")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(store.isBusy)
            .accessibilityLabel(String(localized: "Find pharmacies near me"))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    private func submit() {
        isFocused = false
        Task { await store.searchForAddress() }
    }
}
