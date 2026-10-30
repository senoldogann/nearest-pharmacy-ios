import MapKit
import SwiftUI

struct ContentView: View {
    @State private var store = PharmacyStore()

    var body: some View {
        @Bindable var store = store

        Map(position: $store.camera) {
            if let origin = store.origin {
                Annotation(String(localized: "Your search"), coordinate: origin.coordinate) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 2)
                        .accessibilityHidden(true)
                }
            }

            ForEach(store.pharmacies) { pharmacy in
                Annotation(pharmacy.name, coordinate: pharmacy.point.coordinate, anchor: .bottom) {
                    Button {
                        store.selected = pharmacy
                    } label: {
                        PharmacyMarker(isNearest: pharmacy.id == store.nearest?.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(
                            format: String(localized: "%1$@, %2$@ away"),
                            pharmacy.name,
                            DistanceFormat.text(meters: pharmacy.distanceMeters)
                        )
                    )
                    .accessibilityHint(String(localized: "Shows opening hours and contact details"))
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            SearchPanel(store: store)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ResultsCard(store: store)
        }
        .sheet(item: $store.selected) { pharmacy in
            PharmacyDetailView(pharmacy: pharmacy, originLabel: store.originLabel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task { await store.start() }
    }
}

/// The teardrop pin; the nearest pharmacy gets the accent colour.
private struct PharmacyMarker: View {
    let isNearest: Bool

    var body: some View {
        VStack(spacing: -4) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(isNearest ? Color.accentColor : Color.secondary, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            Triangle()
                .fill(isNearest ? Color.accentColor : Color.secondary)
                .frame(width: 10, height: 6)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ContentView()
}
