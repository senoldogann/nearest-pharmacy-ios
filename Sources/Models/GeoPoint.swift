import CoreLocation
import Foundation

/// A WGS84 point, with the one piece of geometry the app needs: distance.
struct GeoPoint: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    /// Straight-line distance in metres (CoreLocation's great-circle calculation).
    func distance(to other: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

/// A place from the address search.
struct Place: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let point: GeoPoint
}
