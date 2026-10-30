import Foundation
import MapKit
import SwiftUI
import Observation

/// Everything a screen needs: the search, its state, and the map camera.
@MainActor
@Observable
final class PharmacyStore {
    enum Phase: Equatable {
        case idle
        case searching
        case loaded
        case empty
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var pharmacies: [Pharmacy] = []
    private(set) var source: PharmacySource = .overpass
    private(set) var origin: GeoPoint?
    private(set) var originLabel = ""
    private(set) var suggestions: [Place] = []
    private(set) var isLocating = false

    var radiusMeters = 2_000
    var query = ""
    var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.06)
        )
    )
    var selected: Pharmacy?

    private let api: PharmacyAPI
    private let location = LocationProvider()
    private var searchTask: Task<Void, Never>?

    init(api: PharmacyAPI = .live) {
        self.api = api
    }

    var isBusy: Bool { isLocating || phase == .searching }

    var nearest: Pharmacy? { pharmacies.first }

    var statusText: String? {
        switch phase {
        case .idle:
            String(localized: "Share your location or search for an address to see the pharmacies around you.")
        case .searching:
            String(localized: "Finding pharmacies nearby…")
        case .failed(let message):
            message
        case .empty:
            String(localized: "No pharmacy found within this radius. Try a larger one.")
        case .loaded:
            nil
        }
    }

    var resultsTitle: String {
        guard !pharmacies.isEmpty else { return String(localized: "Nearby pharmacies") }
        return String(
            format: String(localized: "%1$d pharmacies within %2$@"),
            pharmacies.count,
            DistanceFormat.text(meters: radiusMeters)
        )
    }

    // MARK: - Actions

    func start() async {
        guard origin == nil, !isBusy else { return }
        await useCurrentLocation(quiet: true)
    }

    func useCurrentLocation(quiet: Bool = false) async {
        guard !isBusy else { return }
        isLocating = true
        defer { isLocating = false }
        if !quiet { phase = .searching }
        do {
            let point = try await location.currentLocation()
            await search(near: point, label: String(localized: "Your location"))
        } catch {
            if !quiet { phase = .failed(error.localizedDescription) }
        }
    }

    func searchForAddress() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            phase = .failed(String(localized: "Type at least two characters of an address."))
            return
        }
        phase = .searching
        do {
            let places = try await api.places(matching: text)
            guard !places.isEmpty else {
                phase = .failed(String(localized: "No place found for that address. Try a street and a city."))
                return
            }
            if places.count == 1 || (places.first?.label.localizedCaseInsensitiveContains(text) == true
                && places[0].label.count < 40) {
                suggestions = []
                await search(near: places[0].point, label: places[0].label)
            } else {
                suggestions = places
                phase = .idle
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func choose(_ place: Place) {
        suggestions = []
        query = place.label
        Task { await search(near: place.point, label: place.label) }
    }

    func search(near point: GeoPoint, label: String) async {
        searchTask?.cancel()
        phase = .searching
        origin = point
        originLabel = label

        let radius = radiusMeters
        let task = Task { [api] in
            do {
                let result = try await api.pharmacies(near: point, radiusMeters: radius)
                guard !Task.isCancelled else { return }
                apply(result)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error.localizedDescription)
            }
        }
        searchTask = task
        await task.value
    }

    func changeRadius(to meters: Int) {
        radiusMeters = meters
        if let origin {
            Task { await search(near: origin, label: originLabel) }
        }
    }

    // MARK: - State

    private func apply(_ result: PharmacySearchResult) {
        pharmacies = result.pharmacies
        source = result.source
        origin = result.origin
        phase = result.pharmacies.isEmpty ? .empty : .loaded
        let span = max(0.008, Double(result.radiusMeters) / 111_320 * 2.4)
        withAnimation(.easeInOut(duration: 0.35)) {
            camera = .region(
                MKCoordinateRegion(
                    center: result.origin.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                )
            )
        }
    }
}

enum DistanceFormat {
    static func text(meters: Int, locale: Locale = .current) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = meters < 1_000 ? 0 : 1
        formatter.numberFormatter.minimumFractionDigits = 0
        let measurement = meters < 1_000
            ? Measurement(value: Double(meters), unit: UnitLength.meters)
            : Measurement(value: Double(meters) / 1_000, unit: UnitLength.kilometers)
        return formatter.string(from: measurement)
    }
}
