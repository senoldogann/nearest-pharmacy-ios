import XCTest
@testable import NearestPharmacy

final class GeoPointTests: XCTestCase {
    func testDistanceBetweenHelsinkiLandmarks() {
        // Kamppi metro station to the railway square, roughly 750 m apart.
        let kamppi = GeoPoint(latitude: 60.168_3, longitude: 24.931_7)
        let railwaySquare = GeoPoint(latitude: 60.171_7, longitude: 24.941_6)
        let distance = kamppi.distance(to: railwaySquare)
        XCTAssertGreaterThan(distance, 500)
        XCTAssertLessThan(distance, 900)
    }

    func testDistanceIsZeroToItselfAndNearlySymmetric() {
        let a = GeoPoint(latitude: 60.1699, longitude: 24.9384)
        let b = GeoPoint(latitude: 61.4978, longitude: 23.7610)
        XCTAssertEqual(a.distance(to: a), 0, accuracy: 0.001)
        // CLLocation measures on the spheroid, so the two directions differ by a
        // fraction of a percent rather than cancelling exactly.
        XCTAssertEqual(a.distance(to: b), b.distance(to: a), accuracy: 1_000)
        XCTAssertGreaterThan(a.distance(to: b), 140_000) // Helsinki–Tampere
    }

    func testValidation() {
        XCTAssertTrue(GeoPoint(latitude: 60, longitude: 24).isValid)
        XCTAssertFalse(GeoPoint(latitude: 91, longitude: 24).isValid)
        XCTAssertFalse(GeoPoint(latitude: 60, longitude: 181).isValid)
        XCTAssertFalse(GeoPoint(latitude: .nan, longitude: 24).isValid)
    }

    func testDistanceFormatting() {
        XCTAssertTrue(DistanceFormat.text(meters: 72, locale: Locale(identifier: "fi_FI")).contains("72"))
        let kilometres = DistanceFormat.text(meters: 2_400, locale: Locale(identifier: "fi_FI"))
        XCTAssertTrue(kilometres.contains("2,4"), "expected a Finnish decimal comma, got \(kilometres)")
    }
}
