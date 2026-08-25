//
//  ChipPlacementUtilsTests.swift
//  MiniproUITests
//

import Foundation
import Testing

@testable import Visual_Minipro

struct ChipPlacementUtilsTests {
    private static func deviceDetails(name: String, package: String) -> DeviceDetails {
        DeviceDetails(
            name: name,
            deviceInfo: [
                KeyValuePair(key: "Name", value: name),
                KeyValuePair(key: "Package", value: package),
            ],
            programmingInfo: [],
            isLogicChip: false
        )
    }

    @Test func placesDipChipInTheSocket() {
        let placement = ChipPlacementUtils.placement(
            for: Self.deviceDetails(name: "W27C512@DIP28", package: "DIP28"),
            programmerModel: .t76
        )
        #expect(placement == ChipPlacement(pinCount: 28, socketPinCount: 48))
        #expect(placement?.socketRows == 24)
        #expect(placement?.chipRows == 14)
        // Bottom aligned: the chip covers socket rows 11 to 24.
        #expect(placement?.firstSocketPin == 11)
        #expect(placement?.socketName == "ZIF48")
    }

    @Test(arguments: [(48, 1), (40, 5), (28, 11), (8, 21)])
    func chipsSitAtTheBottomOfTheSocket(pinCount: Int, firstSocketPin: Int) {
        #expect(
            ChipPlacement(pinCount: pinCount, socketPinCount: 48).firstSocketPin == firstSocketPin
        )
    }

    @Test func placesChipWithoutPackageSuffix() {
        #expect(
            ChipPlacementUtils.placement(
                for: Self.deviceDetails(name: "7404", package: "DIP14"),
                programmerModel: .t48
            ) == ChipPlacement(pinCount: 14, socketPinCount: 40)  // T48 has the smaller socket
        )
    }

    @Test func placesPlccChipViaItsAdapter() {
        // AM27C256@PLCC32 goes in a PLCC32-DIP32 adapter, which then sits in
        // the socket as a DIP32.
        let placement = ChipPlacementUtils.placement(
            for: Self.deviceDetails(name: "AM27C256@PLCC32", package: "PLCC32"),
            programmerModel: .t76
        )
        #expect(placement == ChipPlacement(pinCount: 32, socketPinCount: 48, adapterName: "PLCC32-DIP32"))
        #expect(placement?.firstSocketPin == 9)
    }

    @Test func skipsPlcc44WithTwoPossibleAdapters() {
        // Xgpro ships both PLCC44-DIP40 and PLCC44-DIP44 adapters.
        #expect(
            ChipPlacementUtils.placement(
                for: Self.deviceDetails(name: "AM29F040B@PLCC44", package: "PLCC44"),
                programmerModel: .t76
            ) == nil
        )
    }

    @Test func placesAdapterWithAKnownFootprint() {
        // AFND5608U1@TSOP48 goes on adapter 8, which on a T76 is the
        // T76_F48_05-001 board filling the ZIF48.
        let placement = ChipPlacementUtils.placement(
            for: Self.deviceDetails(name: "AFND5608U1@TSOP48", package: "Adapter008.JPG"),
            programmerModel: .t76
        )
        #expect(
            placement == ChipPlacement(pinCount: 48, socketPinCount: 48, adapterName: "T76_F48_05-001")
        )
        #expect(placement?.firstSocketPin == 1)
    }

    @Test func skipsAdaptersWithAnUnknownFootprint() {
        // Adapter 6 is the T76_P56_08-005 board; Xgpro does not state how many
        // socket pins it takes.
        #expect(
            ChipPlacementUtils.placement(
                for: Self.deviceDetails(name: "SOME-CHIP@SOP56", package: "Adapter006.JPG"),
                programmerModel: .t76
            ) == nil
        )
    }

    @Test func placesLogicIcWithAVariantMarker() {
        // 7406@OC is an open collector 7406, not a chip in an "OC" package.
        #expect(
            ChipPlacementUtils.placement(
                for: Self.deviceDetails(name: "7406@OC", package: "DIP14"),
                programmerModel: .t76
            ) == ChipPlacement(pinCount: 14, socketPinCount: 48)
        )
    }

    @Test func skipsSurfaceMountChipsReportedAsDip() {
        // ACE25AC512G@SON8 reports "DIP8" but goes on an adapter.
        #expect(
            ChipPlacementUtils.placement(
                for: Self.deviceDetails(name: "ACE25AC512G@SON8", package: "DIP8"),
                programmerModel: .t76
            ) == nil
        )
    }

    @Test(arguments: ["Adapter006.JPG", "ICSP only", "DIP41", "DIP56"])
    func skipsPackagesThatDoNotGoStraightIntoTheSocket(package: String) {
        #expect(
            ChipPlacementUtils.placement(
                for: Self.deviceDetails(name: "SOME-CHIP", package: package),
                programmerModel: .t76
            ) == nil
        )
    }

    @Test func usesTheSocketOfTheConnectedProgrammer() {
        #expect(ChipPlacementUtils.socketPinCount(for: .t76) == 48)
        #expect(ChipPlacementUtils.socketPinCount(for: .t56) == 48)
        #expect(ChipPlacementUtils.socketPinCount(for: .t48) == 40)
        #expect(ChipPlacementUtils.socketPinCount(for: .tl866IIPlus) == 40)
        #expect(
            ChipPlacementUtils.placement(
                for: Self.deviceDetails(name: "W27C512@DIP28", package: "DIP28"),
                programmerModel: .t48
            ) == ChipPlacement(pinCount: 28, socketPinCount: 40)
        )
    }

    @Test(arguments: [("DIP8", 8), ("DIP40", 40), ("DIP14", 14)])
    func parsesDipPinCount(packageValue: String, expected: Int) {
        #expect(ChipPlacementUtils.dipPinCount(from: packageValue) == expected)
    }

    @Test(arguments: ["DIP", "DIP7", "DIP2", "dip8", "DIP8@", "Adapter001.JPG"])
    func rejectsInvalidDipPackages(packageValue: String) {
        #expect(ChipPlacementUtils.dipPinCount(from: packageValue) == nil)
    }
}
