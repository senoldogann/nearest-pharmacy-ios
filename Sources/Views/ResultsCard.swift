import SwiftUI

/// The list at the bottom: status, address suggestions, or the pharmacies.
struct ResultsCard: View {
    @Bindable var store: PharmacyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let status = store.statusText {
                StatusRow(
                    text: status,
                    isError: { if case .failed = store.phase { true } else { false } }()
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            if !store.suggestions.isEmpty {
                suggestionList
            } else if !store.pharmacies.isEmpty {
                pharmacyList
            }

            attribution
        }
        .background(.regularMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.resultsTitle)
                    .font(.headline)
                if !store.originLabel.isEmpty {
                    Text(store.originLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)

            Menu {
                Picker(String(localized: "Radius"), selection: radiusBinding) {
                    Text("500 m").tag(500)
                    Text("1 km").tag(1_000)
                    Text("2 km").tag(2_000)
                    Text("5 km").tag(5_000)
                    Text("10 km").tag(10_000)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.dashed")
                    Text(DistanceFormat.text(meters: store.radiusMeters))
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            .accessibilityLabel(String(localized: "Search radius"))
            .accessibilityValue(DistanceFormat.text(meters: store.radiusMeters))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var suggestionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.suggestions) { place in
                    Button {
                        store.choose(place)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle")
                                .foregroundStyle(.secondary)
                            Text(place.label)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(String(localized: "Search the pharmacies here"))
                    Divider().padding(.leading, 44)
                }
            }
        }
        .frame(maxHeight: 260)
    }

    private var pharmacyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.pharmacies) { pharmacy in
                    Button {
                        store.selected = pharmacy
                    } label: {
                        PharmacyRow(pharmacy: pharmacy)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                }
            }
        }
        .frame(maxHeight: 340)
    }

    private var attribution: some View {
        HStack(spacing: 4) {
            Text("©")
            Link("OpenStreetMap contributors",
                 destination: URL(string: "https://www.openstreetmap.org/copyright")!)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Pharmacy data from OpenStreetMap contributors"))
    }

    private var radiusBinding: Binding<Int> {
        Binding(
            get: { store.radiusMeters },
            set: { store.changeRadius(to: $0) }
        )
    }
}

struct PharmacyRow: View {
    let pharmacy: Pharmacy

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(pharmacy.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if let address = pharmacy.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                }
                if let hours = pharmacy.openingHours {
                    Text(hours)
                        .font(.caption2)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Text(DistanceFormat.text(meters: pharmacy.distanceMeters))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "Shows opening hours and contact details"))
    }
}

struct StatusRow: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundStyle(isError ? Color.orange : Color.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
