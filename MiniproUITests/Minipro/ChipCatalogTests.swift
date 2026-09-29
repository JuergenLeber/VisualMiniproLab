//
//  ChipCatalogTests.swift
//  MiniproUITests
//

import Foundation
import Testing

@testable import Visual_Minipro

struct ChipCatalogTests {

    private var infoicPath: URL { Bundle.main.url(forResource: "infoic", withExtension: "xml")! }

    private func catalog(databaseType: String = "INFOICT76") throws -> ChipCatalog {
        let xmlDoc = try XMLDocument(contentsOf: infoicPath)
        return ChipCatalog.build(from: xmlDoc, databaseType: databaseType)
    }

    @Test func testDatabaseTypeFollowsTheProgrammerModel() {
        #expect(ChipCatalog.databaseType(for: .tl866A) == "INFOIC")
        #expect(ChipCatalog.databaseType(for: .tl866CS) == "INFOIC")
        #expect(ChipCatalog.databaseType(for: .tl866IIPlus) == "INFOIC2PLUS")
        #expect(ChipCatalog.databaseType(for: .t48) == "INFOIC2PLUS")
        #expect(ChipCatalog.databaseType(for: .t56) == "INFOIC2PLUS")
        #expect(ChipCatalog.databaseType(for: .t76) == "INFOICT76")
    }

    @Test func testChipsOfSeveralManufacturersBecomeSeveralVariants() throws {
        // M27256@DIP28 is an INTEL part with chip ID 0x8904 and an
        // SGS-THOMSON/ST part with 0x2004.
        let variants = try catalog().variants(for: "M27256@DIP28")
        #expect(variants.count == 2)
        #expect(variants[0].manufacturers == ["INTEL"])
        #expect(variants[0].formattedChipId == "0x8904")
        #expect(variants[1].manufacturers == ["SGS-THOMSON", "ST"])
        #expect(variants[1].formattedChipId == "0x2004")
        #expect(variants.map(\.id) == ["M27256@DIP28#0", "M27256@DIP28#1"])
    }

    @Test func testManufacturersSharingADefinitionAreMerged() throws {
        // SGS-THOMSON and ST declare the same parameters, so telling them apart
        // would only pad the chip list.
        let variants = try catalog().variants(for: "M27256@DIP28")
        let merged = try #require(variants.last)
        #expect(merged.manufacturerLabel == "SGS-THOMSON, ST")
    }

    @Test func testUnambiguousChipsHaveASingleVariantAndNoOverride() throws {
        let variants = try catalog().variants(for: "AM29F040B@DIP32")
        #expect(variants.count == 1)
        #expect(variants[0].definition == nil)
        #expect(!variants[0].manufacturerLabel.isEmpty)
    }

    @Test func testOnlyTheProgrammersDatabaseIsCatalogued() throws {
        // T76-only parts are missing from the TL866A database.
        let t76 = try catalog(databaseType: "INFOICT76")
        let tl866 = try catalog(databaseType: "INFOIC")
        #expect(!t76.variants(for: "M27256@DIP28").isEmpty)
        #expect(!tl866.variants(for: "M27256@DIP28").isEmpty)
        #expect(t76.variants(for: "AT28C64B(Non-Standard)").count == 1)
        #expect(tl866.variants(for: "AT28C64B(Non-Standard)").isEmpty)
    }

    @Test func testUnknownChipsHaveNoVariants() throws {
        #expect(try catalog().variants(for: "NoSuchChip").isEmpty)
    }

    @Test func testChipIdDropsTheDatabasePadding() {
        #expect(variant(chipId: "0x00002004").formattedChipId == "0x2004")
        #expect(variant(chipId: "0x000000bf").formattedChipId == "0xBF")
        #expect(variant(chipId: "0x0000c204").formattedChipId == "0xC204")
        #expect(variant(chipId: "0x00000904").formattedChipId == "0x0904")
        // Chips without an ID must not show one.
        #expect(variant(chipId: "0x00000000").formattedChipId == nil)
        #expect(variant(chipId: nil).formattedChipId == nil)
    }

    @Test func testCustomChipsAreLabelledAsSuch() {
        #expect(variant(manufacturers: ["ATMEL"], isCustom: true).manufacturerLabel == "ATMEL (custom)")
        #expect(variant(manufacturers: ["ATMEL"], isCustom: false).manufacturerLabel == "ATMEL")
    }

    @Test func testListItemsRepeatNamesOncePerVariant() throws {
        let catalog = try catalog()
        let items = ChipListItem.items(for: ["M27256@DIP28", "AM29F040B@DIP32"], catalog: catalog)
        #expect(items.count == 3)
        #expect(items.map(\.name) == ["M27256@DIP28", "M27256@DIP28", "AM29F040B@DIP32"])
        #expect(items[0].manufacturerLabel == "INTEL")
        #expect(items[1].manufacturerLabel == "SGS-THOMSON, ST")
        #expect(Set(items.map(\.id)).count == items.count)
    }

    @Test func testListItemsKeepChipsTheCatalogDoesNotKnow() {
        let items = ChipListItem.items(for: ["7400", "Loading..."], catalog: .empty)
        #expect(items.map(\.name) == ["7400", "Loading..."])
        #expect(items.allSatisfy { $0.variant == nil && $0.manufacturerLabel == nil })
    }

    @Test func testUnambiguousChipsAreProgrammedFromTheFullDatabase() throws {
        let catalog = try catalog()
        let item = ChipListItem(
            name: "AM29F040B@DIP32", variant: catalog.variants(for: "AM29F040B@DIP32").first)
        let fallback = infoicPath
        #expect(
            ChipVariantOverride.infoicPath(for: item, catalog: catalog, fallback: fallback) == fallback)
        #expect(
            ChipVariantOverride.infoicPath(
                for: ChipListItem(name: "7400", variant: nil), catalog: catalog, fallback: fallback)
                == fallback)
    }

    @Test func testTheOverrideDatabaseHoldsOnlyTheSelectedVariant() throws {
        let catalog = try catalog()
        let variants = catalog.variants(for: "M27256@DIP28")
        let selected = try #require(variants.last)
        let fallback = infoicPath
        let url = ChipVariantOverride.infoicPath(
            for: ChipListItem(name: "M27256@DIP28", variant: selected),
            catalog: catalog,
            fallback: fallback
        )
        #expect(url != fallback)

        let overrideDoc = try XMLDocument(contentsOf: url)
        let ics = try #require(try overrideDoc.nodes(forXPath: "//ic") as? [XMLElement])
        #expect(ics.count == 1)
        #expect(ics[0].attribute(forName: "chip_id")?.stringValue == "0x00002004")
        let databases = try #require(try overrideDoc.nodes(forXPath: "//database") as? [XMLElement])
        #expect(databases.count == 1)
        #expect(databases[0].attribute(forName: "type")?.stringValue == "INFOICT76")
        #expect(ics[0].parent?.name == "manufacturer")
        // A chip can point at a configuration by name, so those travel along.
        #expect(!(try overrideDoc.nodes(forXPath: "//configurations/config")).isEmpty)
    }

    private func variant(
        manufacturers: [String] = ["ST"], chipId: String? = nil, isCustom: Bool = false
    ) -> ChipVariant {
        ChipVariant(
            name: "M27256@DIP28",
            manufacturers: manufacturers,
            chipId: chipId,
            isCustom: isCustom,
            databaseType: "INFOICT76",
            definition: nil,
            index: 0
        )
    }
}
