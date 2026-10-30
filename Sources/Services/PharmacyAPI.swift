import Foundation

/// The one object that talks to the network. Both OpenStreetMap services are
/// asked in the same way, and the caller only sees a normalised result.
struct PharmacyAPI: Sendable {
    static let userAgent = "nearest-pharmacy-ios/1.0 (+https://github.com/senoldogann/nearest-pharmacy-ios)"

    let session: URLSession
    let overpassEndpoints: [URL]
    let overpassTimeout: TimeInterval

    init(
        session: URLSession = .shared,
        overpassEndpoints: [URL] = [
            URL(string: "https://overpass-api.de/api/interpreter")!,
            URL(string: "https://overpass.kumi.systems/api/interpreter")!,
        ],
        overpassTimeout: TimeInterval = 8
    ) {
        self.session = session
        self.overpassEndpoints = overpassEndpoints
        self.overpassTimeout = overpassTimeout
    }

    static let live = PharmacyAPI()

    /// Pharmacies within `radiusMeters` of `origin`, nearest first.
    func pharmacies(near origin: GeoPoint, radiusMeters: Int = 2_000) async throws -> PharmacySearchResult {
        guard origin.isValid else { throw PharmacyError.badLocation }
        let radius = min(20_000, max(100, radiusMeters))

        var parsed: [ParsedPharmacy]
        var source = PharmacySource.overpass
        do {
            parsed = try await pharmaciesFromOverpass(origin: origin, radius: radius)
        } catch {
            // Every Overpass instance was busy or unreachable: ask Nominatim,
            // which answers from the same OpenStreetMap data.
            source = .nominatim
            parsed = try await pharmaciesFromNominatim(origin: origin, radius: radius)
        }

        let pharmacies = parsed
            .map { raw in
                Pharmacy(
                    id: raw.id,
                    name: raw.name,
                    point: raw.point,
                    address: raw.address,
                    openingHours: raw.openingHours,
                    phone: raw.phone,
                    website: raw.website,
                    wheelchairAccessible: raw.wheelchair,
                    distanceMeters: Int(origin.distance(to: raw.point).rounded())
                )
            }
            .filter { $0.distanceMeters <= radius }
            .sorted { $0.distanceMeters < $1.distanceMeters }

        return PharmacySearchResult(origin: origin, radiusMeters: radius, source: source, pharmacies: pharmacies)
    }

    func places(matching query: String) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        await NominatimThrottle.shared.waitForTurn()
        var request = URLRequest(url: Nominatim.geocodeURL(query: trimmed))
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await send(request, service: "Nominatim")
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PharmacyError.network(String(localized: "The address search answered with an error."))
        }
        return try Nominatim.parsePlaces(data)
    }

    // MARK: - Sources

    private func pharmaciesFromOverpass(origin: GeoPoint, radius: Int) async throws -> [ParsedPharmacy] {
        let query = Overpass.query(latitude: origin.latitude, longitude: origin.longitude, radiusMeters: radius)
        var body = URLComponents()
        body.queryItems = [URLQueryItem(name: "data", value: query)]
        let payload = Data((body.percentEncodedQuery ?? "").utf8)

        var lastFailure: Error = PharmacyError.network(String(localized: "No map server answered."))
        for endpoint in overpassEndpoints {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.httpBody = payload
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = overpassTimeout
            do {
                let (data, response) = try await send(request, service: "Overpass")
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    lastFailure = PharmacyError.network(String(localized: "The map server is busy."))
                    continue
                }
                return try Overpass.parse(data)
            } catch {
                lastFailure = error
            }
        }
        throw lastFailure
    }

    private func pharmaciesFromNominatim(origin: GeoPoint, radius: Int) async throws -> [ParsedPharmacy] {
        await NominatimThrottle.shared.waitForTurn()
        var request = URLRequest(url: Nominatim.pharmaciesURL(
            latitude: origin.latitude, longitude: origin.longitude, radiusMeters: radius
        ))
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await send(request, service: "Nominatim")
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PharmacyError.network(String(localized: "The address index is busy too."))
        }
        return try Nominatim.parsePharmacies(data)
    }

    /// One request, with transport errors turned into a readable message.
    private func send(_ request: URLRequest, service: String) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw PharmacyError.network(String(localized: "\(service) did not answer in time."))
        }
    }
}

/// Nominatim's usage policy allows one request a second.
actor NominatimThrottle {
    static let shared = NominatimThrottle()

    private let interval: TimeInterval
    private var lastRequest: Date?

    init(interval: TimeInterval = 1.1) {
        self.interval = interval
    }

    func waitForTurn() async {
        if let lastRequest {
            let remaining = interval - Date().timeIntervalSince(lastRequest)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
        lastRequest = Date()
    }
}
