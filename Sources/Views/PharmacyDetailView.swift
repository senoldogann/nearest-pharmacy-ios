import SwiftUI

/// What you need at the door: distance, address, hours, a phone number and a
/// link to directions.
struct PharmacyDetailView: View {
    let pharmacy: Pharmacy
    let originLabel: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    title

                    VStack(alignment: .leading, spacing: 14) {
                        if let address = pharmacy.address {
                            DetailLine(icon: "mappin.and.ellipse", title: address)
                        }
                        if let hours = pharmacy.openingHours {
                            DetailLine(icon: "clock", title: hours)
                        }
                        if let accessible = pharmacy.wheelchairAccessible {
                            DetailLine(
                                icon: accessible ? "figure.roll" : "figure.walk",
                                title: accessible
                                    ? String(localized: "Step-free entrance")
                                    : String(localized: "No step-free entrance recorded")
                            )
                        }
                    }

                    actions

                    Text("Distances are straight-line, not walking routes. Pharmacy data © OpenStreetMap contributors.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pharmacy.name)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .accessibilityHidden(true)
                Text(DistanceFormat.text(meters: pharmacy.distanceMeters))
                    .monospacedDigit()
                if !originLabel.isEmpty {
                    Text("· \(originLabel)")
                        .lineLimit(1)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(
                    format: String(localized: "%1$@ away from %2$@"),
                    DistanceFormat.text(meters: pharmacy.distanceMeters),
                    originLabel.isEmpty ? String(localized: "your search") : originLabel
                )
            )
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if let phoneURL = pharmacy.phoneURL {
                ActionButton(
                    title: pharmacy.phone ?? String(localized: "Call"),
                    subtitle: String(localized: "Call the pharmacy"),
                    icon: "phone.fill",
                    url: phoneURL
                )
            }
            if let website = pharmacy.website {
                ActionButton(
                    title: String(localized: "Website"),
                    subtitle: website.host() ?? website.absoluteString,
                    icon: "safari.fill",
                    url: website
                )
            }
            if let directions = pharmacy.directionsURL {
                ActionButton(
                    title: String(localized: "Directions"),
                    subtitle: String(localized: "Open in OpenStreetMap"),
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    url: directions
                )
            }
        }
    }
}

private struct DetailLine: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let url: URL
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}
