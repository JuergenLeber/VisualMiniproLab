//
//  XgproAdapterCatalog.swift
//  Visual Minipro
//

import Foundation

struct XgproAdapter: Equatable, Hashable {
    /// The adapter Xgpro names for the connected programmer, e.g.
    /// "T76_F48_05-001".
    let name: String
    /// Image names Xgpro would show, most specific first.
    let imageNames: [String]
    /// How many socket pins the adapter occupies, when Xgpro states it.
    let footprintPins: Int?
}

/// The adapter table lifted from Xgpro's executable, keyed by the adapter index
/// minipro reports as "Package: AdapterNNN.JPG". Each record holds the adapter
/// name Xgpro shows for a T76, the name it shows for the older programmers, and
/// the pictures for each model.
class XgproAdapterCatalog {
    private struct Entry {
        let t76Name: String
        let legacyName: String
        let images: [String]
        /// Only set where an adapter name states the footprint ("SOP44->DIP44")
        /// or where it is confirmed against Xgpro's own socket diagram.
        let t76FootprintPins: Int?
        let legacyFootprintPins: Int?
    }

    // The T76 puts most flash packages on one 48 pin adapter, T76_F48_05-001,
    // which Xgpro's "Location in Socket" diagram shows filling the ZIF48.
    private static let universalT76FlashAdapter = "T76_F48_05-001"

    private static let entries: [Int: Entry] = [
        1: Entry(
            t76Name: universalT76FlashAdapter, legacyName: "ADP_F48-EX-1",
            images: ["Adapter001.jpg", "T56T48.jpg", "T48T48.jpg"],
            t76FootprintPins: 48, legacyFootprintPins: nil
        ),
        2: Entry(
            t76Name: "SOP44->DIP44", legacyName: "ADP_S44-EX-1",
            images: ["Adapter002.jpg", "T56SOP44.jpg", "T48SOP44.jpg"],
            t76FootprintPins: 44, legacyFootprintPins: nil
        ),
        3: Entry(
            t76Name: universalT76FlashAdapter, legacyName: "ADP_F48-EX-1",
            images: ["Adapter003.jpg", "T56T48.jpg", "T48T48.jpg"],
            t76FootprintPins: 48, legacyFootprintPins: nil
        ),
        4: Entry(
            t76Name: universalT76FlashAdapter, legacyName: "ADP_F40-0.5-14",
            images: ["Adapter004.jpg", "T56T48.jpg", "T48T40B.jpg"],
            t76FootprintPins: 48, legacyFootprintPins: nil
        ),
        5: Entry(
            t76Name: universalT76FlashAdapter, legacyName: "TSOP32->DIP32",
            images: ["Adapter005.jpg", "T56T48.jpg", "T48T32.jpg"],
            t76FootprintPins: 48, legacyFootprintPins: 32
        ),
        6: Entry(
            t76Name: "T76_P56_08-005", legacyName: "SOP56 SV29802",
            images: ["Adapter006.jpg", "T76P56.jpg", "T48P56.jpg"],
            t76FootprintPins: nil, legacyFootprintPins: nil
        ),
        7: Entry(
            t76Name: "TQFP64->DIP40", legacyName: "TQFP64 DIY",
            images: ["Adapter007.jpg", "T56TQFP64_ATMEGA.jpg", "T48TQFP64_ATMEGA.jpg"],
            t76FootprintPins: 40, legacyFootprintPins: nil
        ),
        8: Entry(
            t76Name: universalT76FlashAdapter, legacyName: "ADP_F48-EX-2",
            images: ["Adapter008.jpg", "T56T48.jpg", "T48T48N.jpg"],
            t76FootprintPins: 48, legacyFootprintPins: nil
        ),
        9: Entry(
            t76Name: universalT76FlashAdapter, legacyName: "ADP_F48-EX-3",
            images: ["Adapter009.jpg", "T56T48.jpg", "T48T48N.jpg"],
            t76FootprintPins: 48, legacyFootprintPins: nil
        ),
        10: Entry(
            t76Name: "LQFP128-DIP8", legacyName: "LQFP128-DIP8",
            images: ["Adapter010.jpg", "T56KB9012ADP.jpg", "T48KB9012ADP.jpg"],
            t76FootprintPins: 8, legacyFootprintPins: 8
        ),
        11: Entry(
            t76Name: "T76_F56_05-002", legacyName: "TSOP56",
            images: ["AdapterT56.jpg", "T76T56.jpg", "T48T56.jpg"],
            t76FootprintPins: nil, legacyFootprintPins: nil
        ),
        12: Entry(
            t76Name: "ITE-TQFP128", legacyName: "IT8xxxx-TQFP128",
            images: ["AdapterITE.jpg"],
            t76FootprintPins: nil, legacyFootprintPins: nil
        ),
        13: Entry(
            t76Name: "TSOP32-DIP32", legacyName: "TSOP32-DIP32",
            images: ["T86T32A.jpg", "T56T32A.jpg", "T48T32A.jpg"],
            t76FootprintPins: 32, legacyFootprintPins: 32
        ),
    ]

    private static let adapterReference = /^Adapter([0-9]+)\.JPG$/

    static func adapterIndex(from packageValue: String) -> Int? {
        guard let match = try? adapterReference.wholeMatch(in: packageValue) else {
            return nil
        }
        return Int(match.1)
    }

    static func adapter(index: Int, programmerModel: ProgrammerModel) -> XgproAdapter? {
        guard let entry = entries[index] else {
            return nil
        }
        let isT76 = programmerModel == .t76
        return XgproAdapter(
            name: isT76 ? entry.t76Name : entry.legacyName,
            imageNames: preferredImages(entry.images, programmerModel: programmerModel),
            footprintPins: isT76 ? entry.t76FootprintPins : entry.legacyFootprintPins
        )
    }

    static func adapter(for packageValue: String, programmerModel: ProgrammerModel) -> XgproAdapter? {
        guard let index = adapterIndex(from: packageValue) else {
            return nil
        }
        return adapter(index: index, programmerModel: programmerModel)
    }

    /// Xgpro ships a picture per programmer. Take the one for the connected
    /// programmer, then a picture that belongs to no particular model, and
    /// never one belonging to a different programmer.
    private static func preferredImages(_ images: [String], programmerModel: ProgrammerModel) -> [String] {
        let modelPrefixes = ["T48", "T56", "T76", "T86"]
        let ownPrefix = imagePrefix(for: programmerModel)
        let own = images.filter { $0.hasPrefix(ownPrefix) }
        let generic = images.filter { image in !modelPrefixes.contains { image.hasPrefix($0) } }
        return own + generic
    }

    private static func imagePrefix(for programmerModel: ProgrammerModel) -> String {
        switch programmerModel {
        case .tl866A, .tl866CS, .tl866IIPlus:
            return "T86"
        case .t48:
            return "T48"
        case .t56:
            return "T56"
        case .t76:
            return "T76"
        }
    }
}
