import Foundation

/// A pharmacy as the app shows it: normalised from OpenStreetMap and measured
/// against the search origin.
struct Pharmacy: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let point: GeoPoint
    let address: String?
    let openingHours: String?
    let phone: String?
    let website: URL?
    let wheelchairAccessible: Bool?
    let distanceMeters: Int

    var phoneURL: URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel://\(digits)")
    }

    var directionsURL: URL? {
        var components = URLComponents(string: "https://www.openstreetmap.org/directions")
        components?.queryItems = [
            URLQueryItem(name: "from", value: ""),
            URLQueryItem(name: "to", value: "\(point.latitude),\(point.longitude)"),
        ]
        return components?.url
    }
}

/// Which OpenStreetMap service answered.
enum PharmacySource: String, Sendable {
    case overpass
    case nominatim
}

struct PharmacySearchResult: Sendable {
    let origin: GeoPoint
    let radiusMeters: Int
    let source: PharmacySource
    let pharmacies: [Pharmacy]
}

/// A pharmacy as parsed from the map data, before it is measured and sorted.
struct ParsedPharmacy: Equatable, Sendable {
    var id: String
    var name: String
    var point: GeoPoint
    var address: String?
    var openingHours: String?
    var phone: String?
    var website: URL?
    var wheelchair: Bool?
}

enum PharmacyError: LocalizedError, Equatable {
    case badLocation
    case noResults
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badLocation:
            String(localized: "That place has no usable coordinates.")
        case .noResults:
            String(localized: "No pharmacy found. Try a larger radius or another address.")
        case .network(let detail):
            String(localized: "Could not reach OpenStreetMap. \(detail)")
        }
    }
}
