import XCTest
@testable import NearestPharmacy

final class PharmacyAPITests: XCTestCase {
    private let origin = GeoPoint(latitude: 60.1699, longitude: 24.9384)

    func testOverpassAnswerIsMeasuredAndSortedNearestFirst() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let body = """
            {"elements":[
              {"type":"node","id":1,"lat":60.1800,"lon":24.9384,"tags":{"name":"Far"}},
              {"type":"node","id":2,"lat":60.1701,"lon":24.9384,"tags":{"name":"Close"}},
              {"type":"node","id":3,"lat":60.3000,"lon":24.9384,"tags":{"name":"Outside"}}
            ]}
            """
            return (200, Data(body.utf8))
        }

        let api = makeAPI()
        let result = try await api.pharmacies(near: origin, radiusMeters: 2_000)

        XCTAssertEqual(result.source, .overpass)
        XCTAssertEqual(result.pharmacies.map(\.name), ["Close", "Far"])
        XCTAssertEqual(result.pharmacies[0].distanceMeters, 22)
        XCTAssertLessThan(result.pharmacies[0].distanceMeters, result.pharmacies[1].distanceMeters)
        XCTAssertFalse(result.pharmacies.contains { $0.name == "Outside" },
                       "a pharmacy outside the radius must be dropped")
    }

    func testFallsBackToNominatimWhenEveryOverpassMirrorIsBusy() async throws {
        StubURLProtocol.handler = { request in
            if request.url?.host == "overpass-api.de" || request.url?.host == "overpass.kumi.systems" {
                return (503, Data("busy".utf8))
            }
            let body = """
            [{"place_id":1,"osm_type":"node","osm_id":9,"lat":"60.1695","lon":"24.9395",
              "category":"amenity","type":"pharmacy","name":"Yliopiston apteekki",
              "display_name":"Yliopiston apteekki, Helsinki","address":{"road":"Mannerheimintie","city":"Helsinki"}}]
            """
            return (200, Data(body.utf8))
        }

        let result = try await makeAPI().pharmacies(near: origin, radiusMeters: 2_000)
        XCTAssertEqual(result.source, .nominatim)
        XCTAssertEqual(result.pharmacies.first?.name, "Yliopiston apteekki")
        XCTAssertEqual(result.pharmacies.first?.address, "Mannerheimintie, Helsinki")
    }

    func testBothSourcesFailingIsAnErrorNotAnEmptyList() async {
        StubURLProtocol.handler = { _ in (500, Data()) }
        do {
            _ = try await makeAPI().pharmacies(near: origin, radiusMeters: 2_000)
            XCTFail("expected a network error")
        } catch let error as PharmacyError {
            guard case .network = error else { return XCTFail("unexpected error \(error)") }
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testInvalidCoordinatesAreRejectedBeforeAnyRequest() async {
        StubURLProtocol.handler = { _ in
            XCTFail("no request should be made")
            return (500, Data())
        }
        do {
            _ = try await makeAPI().pharmacies(near: GeoPoint(latitude: 200, longitude: 0))
            XCTFail("expected badLocation")
        } catch let error as PharmacyError {
            XCTAssertEqual(error, .badLocation)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testRadiusIsClampedToWhatTheServicesSupport() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"elements":[]}"#.utf8)) }
        let result = try await makeAPI().pharmacies(near: origin, radiusMeters: 999_999)
        XCTAssertEqual(result.radiusMeters, 20_000)
    }

    // MARK: - Helpers

    private func makeAPI() -> PharmacyAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return PharmacyAPI(
            session: URLSession(configuration: configuration),
            overpassEndpoints: [
                URL(string: "https://overpass-api.de/api/interpreter")!,
                URL(string: "https://overpass.kumi.systems/api/interpreter")!,
            ],
            overpassTimeout: 2
        )
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
