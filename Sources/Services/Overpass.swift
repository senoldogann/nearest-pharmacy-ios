import Foundation

/// Overpass QL for "every pharmacy node within a radius", and the parser that
/// turns its JSON into `ParsedPharmacy` values.
enum Overpass {
    static func query(latitude: Double, longitude: Double, radiusMeters: Int) -> String {
        "[out:json][timeout:10];node[\"amenity\"=\"pharmacy\"](around:\(radiusMeters),\(latitude),\(longitude));out body;"
    }

    static func parse(_ data: Data) throws -> [ParsedPharmacy] {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw PharmacyError.network(String(localized: "The map data could not be read."))
        }
        return response.elements.compactMap { element in
            guard let latitude = element.lat, let longitude = element.lon else { return nil }
            let point = GeoPoint(latitude: latitude, longitude: longitude)
            guard point.isValid else { return nil }
            let tags = element.tags ?? [:]
            return ParsedPharmacy(
                id: "\(element.type)/\(element.id)",
                name: name(from: tags),
                point: point,
                address: address(from: tags),
                openingHours: tags["opening_hours"]?.trimmedNonEmpty,
                phone: (tags["phone"] ?? tags["contact:phone"])?.trimmedNonEmpty,
                website: website(from: tags),
                wheelchair: wheelchair(from: tags)
            )
        }
    }

    private static func name(from tags: [String: String]) -> String {
        tags["name"]?.trimmedNonEmpty
            ?? tags["operator"]?.trimmedNonEmpty
            ?? String(localized: "Pharmacy")
    }

    private static func address(from tags: [String: String]) -> String? {
        let street = [tags["addr:street"], tags["addr:housenumber"]]
            .compactMap { $0?.trimmedNonEmpty }
            .joined(separator: " ")
        let city = [tags["addr:postcode"], tags["addr:city"]]
            .compactMap { $0?.trimmedNonEmpty }
            .joined(separator: " ")
        let parts = [street, city].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func website(from tags: [String: String]) -> URL? {
        guard let raw = (tags["website"] ?? tags["contact:website"])?.trimmedNonEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: "https://\(raw)")
    }

    private static func wheelchair(from tags: [String: String]) -> Bool? {
        switch tags["wheelchair"] {
        case "yes", "designated", "limited": true
        case "no": false
        default: nil
        }
    }

    private struct Response: Decodable {
        let elements: [Element]
    }

    private struct Element: Decodable {
        let type: String
        let id: Int
        let lat: Double?
        let lon: Double?
        let tags: [String: String]?
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
