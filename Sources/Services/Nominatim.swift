import Foundation

/// Nominatim, OpenStreetMap's own search, used when every Overpass instance is
/// busy or unreachable. It answers "pharmacy near here" from the same data.
enum Nominatim {
    static let searchURL = URL(string: "https://nominatim.openstreetmap.org/search")!

    /// A square around the origin as Nominatim's `viewbox`: left, top, right, bottom.
    static func viewbox(latitude: Double, longitude: Double, radiusMeters: Int) -> String {
        let latDelta = Double(radiusMeters) / 111_320
        let lonDelta = Double(radiusMeters) / (111_320 * max(0.01, cos(latitude * .pi / 180)))
        return [longitude - lonDelta, latitude + latDelta, longitude + lonDelta, latitude - latDelta]
            .map { String(format: "%.6f", $0) }
            .joined(separator: ",")
    }

    static func pharmaciesURL(latitude: Double, longitude: Double, radiusMeters: Int) -> URL {
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "pharmacy"),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "bounded", value: "1"),
            URLQueryItem(name: "viewbox", value: viewbox(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)),
            URLQueryItem(name: "extratags", value: "1"),
            URLQueryItem(name: "addressdetails", value: "1"),
        ]
        return components.url!
    }

    static func geocodeURL(query: String) -> URL {
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "addressdetails", value: "0"),
        ]
        return components.url!
    }

    static func parsePharmacies(_ data: Data) throws -> [ParsedPharmacy] {
        let rows: [Row]
        do {
            rows = try JSONDecoder().decode([Row].self, from: data)
        } catch {
            throw PharmacyError.network(String(localized: "The map data could not be read."))
        }
        return rows.compactMap { row in
            guard row.category == "amenity", row.type == "pharmacy",
                  let latitude = row.latitudeValue, let longitude = row.longitudeValue else { return nil }
            let point = GeoPoint(latitude: latitude, longitude: longitude)
            guard point.isValid else { return nil }
            let tags = row.extratags ?? [:]
            let addressParts = [
                [row.address?.road, row.address?.houseNumber].compactMap { $0?.trimmedNonEmpty }
                    .joined(separator: " "),
                [row.address?.postcode, row.address?.city ?? row.address?.town ?? row.address?.village]
                    .compactMap { $0?.trimmedNonEmpty }.joined(separator: " "),
            ].filter { !$0.isEmpty }
            return ParsedPharmacy(
                id: "\(row.osmType ?? "osm")/\(row.osmID ?? row.placeID ?? 0)",
                name: (row.name?.trimmedNonEmpty ?? String(localized: "Pharmacy")),
                point: point,
                address: addressParts.isEmpty ? nil : addressParts.joined(separator: ", "),
                openingHours: tags["opening_hours"]?.trimmedNonEmpty,
                phone: (tags["phone"] ?? tags["contact:phone"])?.trimmedNonEmpty,
                website: (tags["website"] ?? tags["contact:website"]).flatMap {
                    URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines))
                },
                wheelchair: tags["wheelchair"] == "yes" ? true : tags["wheelchair"] == "no" ? false : nil
            )
        }
    }

    static func parsePlaces(_ data: Data) throws -> [Place] {
        let rows: [Row]
        do {
            rows = try JSONDecoder().decode([Row].self, from: data)
        } catch {
            throw PharmacyError.network(String(localized: "The address search could not be read."))
        }
        return rows.compactMap { row in
            guard let latitude = row.latitudeValue, let longitude = row.longitudeValue,
                  let label = row.displayName?.trimmedNonEmpty else { return nil }
            let point = GeoPoint(latitude: latitude, longitude: longitude)
            guard point.isValid else { return nil }
            return Place(id: "\(row.osmType ?? "place")/\(row.placeID ?? 0)", label: label, point: point)
        }
    }

    private struct Row: Decodable {
        let placeID: Int?
        let osmType: String?
        let osmID: Int?
        let latitude: String?
        let longitude: String?
        let category: String?
        let type: String?
        let name: String?
        let displayName: String?
        let address: Address?
        let extratags: [String: String]?

        var latitudeValue: Double? { latitude.flatMap(Double.init) }
        var longitudeValue: Double? { longitude.flatMap(Double.init) }

        enum CodingKeys: String, CodingKey {
            case placeID = "place_id"
            case osmType = "osm_type"
            case osmID = "osm_id"
            case latitude = "lat"
            case longitude = "lon"
            case category
            case type
            case name
            case displayName = "display_name"
            case address
            case extratags
        }
    }

    struct Address: Decodable {
        let road: String?
        let houseNumber: String?
        let postcode: String?
        let city: String?
        let town: String?
        let village: String?

        enum CodingKeys: String, CodingKey {
            case road
            case houseNumber = "house_number"
            case postcode
            case city
            case town
            case village
        }
    }
}
