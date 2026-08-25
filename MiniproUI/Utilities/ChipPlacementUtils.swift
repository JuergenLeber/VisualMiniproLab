//
//  ChipPlacementUtils.swift
//  Visual Minipro
//

import Foundation

/// Where a chip goes in the programmer's ZIF socket: at the bottom of the
/// socket, away from the lever, with the notch pointing up.
struct ChipPlacement: Equatable, Hashable {
    let pinCount: Int
    let socketPinCount: Int
    /// The adapter the chip needs first, e.g. "PLCC32-DIP32". The adapter is
    /// what goes in the socket, taking the pin count of its DIP side.
    var adapterName: String? = nil

    var socketRows: Int { socketPinCount / 2 }
    var chipRows: Int { pinCount / 2 }

    /// What Xgpro calls the socket, e.g. "ZIF48".
    var socketName: String { "ZIF\(socketPinCount)" }

    /// The socket pin the chip's pin 1 sits in. Bottom aligned, so a 28 pin
    /// chip in a ZIF48 socket starts at socket pin 11, not socket pin 1.
    var firstSocketPin: Int { socketRows - chipRows + 1 }
}

class ChipPlacementUtils {
    private static let dipPackage = /^DIP([0-9]+)$/
    private static let plccPackage = /^PLCC([0-9]+)$/
    /// A package in a device name is letters followed by pins: DIP28, SON8,
    /// TSOP48. Markers like the "OC" of 7406@OC are not packages.
    private static let packageLikeSuffix = /^[A-Za-z]+[0-9]+/

    /// Xgpro's PLCC adapters, as named in the Xgpro executable. PLCC44 is left
    /// out: it ships as both a PLCC44-DIP40 and a PLCC44-DIP44 adapter, so the
    /// footprint cannot be told from the chip alone.
    private static let plccAdapterPinCounts = [20: 20, 28: 28, 32: 32]

    static func socketPinCount(for programmerModel: ProgrammerModel) -> Int? {
        switch programmerModel {
        case .tl866A, .tl866CS, .tl866IIPlus, .t48:
            return 40
        case .t56, .t76:
            return 48
        }
    }

    static func placement(for deviceDetails: DeviceDetails, programmerModel: ProgrammerModel) -> ChipPlacement? {
        guard
            let socketPinCount = socketPinCount(for: programmerModel),
            let packageValue = deviceDetails.deviceInfo.first(where: { $0.key == "Package" })?.value,
            packageMatchesDeviceName(packageValue, deviceName: deviceDetails.name)
                || XgproAdapterCatalog.adapterIndex(from: packageValue) != nil
        else {
            return nil
        }

        var adapterName: String?
        var pinCount: Int?
        if let adapter = XgproAdapterCatalog.adapter(for: packageValue, programmerModel: programmerModel) {
            // The adapter goes in the socket, so it brings its own footprint.
            pinCount = adapter.footprintPins
            adapterName = adapter.name
        } else if let dipPinCount = dipPinCount(from: packageValue) {
            pinCount = dipPinCount
        } else if let plccPinCount = plccPinCount(from: packageValue),
            let adapterPinCount = plccAdapterPinCounts[plccPinCount]
        {
            pinCount = adapterPinCount
            adapterName = "PLCC\(plccPinCount)-DIP\(adapterPinCount)"
        }

        guard let pinCount, pinCount <= socketPinCount else {
            return nil
        }
        return ChipPlacement(pinCount: pinCount, socketPinCount: socketPinCount, adapterName: adapterName)
    }

    static func dipPinCount(from packageValue: String) -> Int? {
        pinCount(from: packageValue, package: dipPackage)
    }

    static func plccPinCount(from packageValue: String) -> Int? {
        pinCount(from: packageValue, package: plccPackage)
    }

    private static func pinCount(from packageValue: String, package: Regex<(Substring, Substring)>) -> Int? {
        guard
            let match = try? package.wholeMatch(in: packageValue),
            let pinCount = Int(match.1),
            pinCount >= 4,
            pinCount.isMultiple(of: 2)
        else {
            return nil
        }
        return pinCount
    }

    /// minipro reports the DIP equivalent for surface mount parts, e.g.
    /// ACE25AC512G@SON8 is "DIP8". Those go on an adapter this cannot identify,
    /// so only go ahead when the device name carries the same package.
    static func packageMatchesDeviceName(_ packageValue: String, deviceName: String) -> Bool {
        guard
            let deviceSuffix = deviceName.split(separator: "@").dropFirst().last,
            String(deviceSuffix).contains(packageLikeSuffix)
        else {
            // No package in the name: logic ICs, and variant markers such as
            // the open collector 7406@OC. Go by what minipro reports.
            return true
        }
        return deviceSuffix.uppercased() == packageValue.uppercased()
    }
}
