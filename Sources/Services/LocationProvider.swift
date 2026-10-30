import CoreLocation
import Foundation

/// One location fix, delivered as an async value.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case denied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied:
                String(localized: "Location access is off. Allow it in Settings, or search for an address.")
            case .unavailable:
                String(localized: "Your location is not available right now. Search for an address instead.")
            }
        }
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<GeoPoint, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isDenied: Bool {
        let status = manager.authorizationStatus
        return status == .denied || status == .restricted
    }

    func currentLocation() async throws -> GeoPoint {
        guard !isDenied else { throw LocationError.denied }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation?.resume(throwing: CancellationError())
            self.continuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            manager.requestLocation()
        }
    }

    private func finish(with result: Result<GeoPoint, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let point = GeoPoint(location.coordinate)
        Task { @MainActor in self.finish(with: .success(point)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        Task { @MainActor in
            self.finish(with: .failure(denied ? LocationError.denied : LocationError.unavailable))
        }
    }
}
