import XCTest
@testable import NearestPharmacy

final class MapDataTests: XCTestCase {
    func testOverpassQueryAsksForPharmaciesInARadius() {
        let query = Overpass.query(latitude: 60.1699, longitude: 24.9384, radiusMeters: 2_000)
        XCTAssertTrue(query.contains("amenity\"=\"pharmacy"))
        XCTAssertTrue(query.contains("around:2000,60.1699,24.9384"))
        XCTAssertTrue(query.contains("out body"))
    }

    func testOverpassParsingNormalisesTags() throws {
        let json = """
        {"elements":[
          {"type":"node","id":1,"lat":60.1695,"lon":24.9395,"tags":{"name":"Yliopiston apteekki","addr:street":"Mannerheimintie","addr:housenumber":"5","addr:postcode":"00100","addr:city":"Helsinki","opening_hours":"08:00-24:00","phone":"+358 300 20200","website":"www.yliopistonapteekki.fi","wheelchair":"yes"}},
          {"type":"node","id":2,"lat":60.1700,"lon":24.9416,"tags":{}},
          {"type":"node","id":3,"tags":{"name":"No coordinates"}}
        ]}
        """.data(using: .utf8)!

        let parsed = try Overpass.parse(json)
        XCTAssertEqual(parsed.count, 2)

        let first = parsed[0]
        XCTAssertEqual(first.id, "node/1")
        XCTAssertEqual(first.name, "Yliopiston apteekki")
        XCTAssertEqual(first.address, "Mannerheimintie 5, 00100 Helsinki")
        XCTAssertEqual(first.openingHours, "08:00-24:00")
        XCTAssertEqual(first.phone, "+358 300 20200")
        XCTAssertEqual(first.website?.host(), "www.yliopistonapteekki.fi")
        XCTAssertEqual(first.wheelchair, true)
        XCTAssertEqual(first.point.latitude, 60.1695, accuracy: 0.0001)
    }

    func testUnnamedPharmacyGetsAFallbackName() throws {
        let json = #"{"elements":[{"type":"node","id":2,"lat":60.17,"lon":24.94}]}"#.data(using: .utf8)!
        let parsed = try Overpass.parse(json)
        XCTAssertEqual(parsed.first?.name, "Pharmacy")
    }

    func testBrokenJsonThrowsAReadableError() {
        XCTAssertThrowsError(try Overpass.parse(Data("not json".utf8)))
    }

    func testNominatimViewboxSurroundsTheOrigin() {
        let box = Nominatim.viewbox(latitude: 60, longitude: 24, radiusMeters: 1_000)
        let parts = box.split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 4)
        XCTAssertLessThan(parts[0], 24) // left
        XCTAssertGreaterThan(parts[2], 24) // right
        XCTAssertGreaterThan(parts[1], 60) // top
        XCTAssertLessThan(parts[3], 60) // bottom
    }

    func testNominatimPharmaciesAreFilteredAndParsed() throws {
        let json = """
        [
          {"place_id":10,"osm_type":"node","osm_id":7,"lat":"60.1695","lon":"24.9395","category":"amenity","type":"pharmacy","name":"Apteekki","display_name":"Apteekki, Helsinki",
           "address":{"road":"Mannerheimintie","house_number":"5","postcode":"00100","city":"Helsinki"},
           "extratags":{"opening_hours":"Mo-Fr 08:00-19:00","wheelchair":"no"}},
          {"place_id":11,"osm_type":"way","osm_id":8,"lat":"60.17","lon":"24.94","category":"shop","type":"supermarket","display_name":"K-market"},
          {"place_id":12,"osm_type":"node","osm_id":9,"lat":"60.171","lon":"24.942","category":"amenity","type":"pharmacy","display_name":"Nimetön apteekki"}
        ]
        """.data(using: .utf8)!

        let parsed = try Nominatim.parsePharmacies(json)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].id, "node/7")
        XCTAssertEqual(parsed[0].address, "Mannerheimintie 5, 00100 Helsinki")
        XCTAssertEqual(parsed[0].openingHours, "Mo-Fr 08:00-19:00")
        XCTAssertEqual(parsed[0].wheelchair, false)
        XCTAssertEqual(parsed[1].name, "Pharmacy")
    }

    func testPlaceSearchParsesLabels() throws {
        let json = """
        [{"place_id":1,"osm_type":"node","osm_id":2,"lat":"60.1676","lon":"24.9317",
          "display_name":"Kamppi, Helsinki, Finland"}]
        """.data(using: .utf8)!

        let places = try Nominatim.parsePlaces(json)
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].label, "Kamppi, Helsinki, Finland")
        XCTAssertEqual(places[0].point.latitude, 60.1676, accuracy: 0.0001)
    }
}
