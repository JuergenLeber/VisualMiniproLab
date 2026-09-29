//
//  SupportedDevicesProcessor.swift
//  MiniproUI
//
//  Created by Pawel Kadluczka on 2/9/25.
//

import Foundation

struct SupportedDevices {
    let logicICs: [String]
    let eepromICs: [String]
    let catalog: ChipCatalog
    /// The chip list rows: one per manufacturer variant of an EEPROM name.
    let eepromChips: [ChipListItem]
    let logicChips: [ChipListItem]

    init(logicICs: [String], eepromICs: [String], catalog: ChipCatalog = .empty) {
        self.logicICs = logicICs
        self.eepromICs = eepromICs
        self.catalog = catalog
        self.eepromChips = ChipListItem.items(for: eepromICs, catalog: catalog)
        // Logic ICs come from logicic.xml, which knows a single manufacturer.
        self.logicChips = ChipListItem.items(for: logicICs, catalog: .empty)
    }
}

class SupportedDevicesProcessor {
    private static func getICNames(from xmlDoc: XMLDocument?) -> Set<String> {
        var icNames = Set<String>()
        if let nodes = try? xmlDoc?.nodes(forXPath: "//ic") as? [XMLElement] {
            for n in nodes {
                let nameList = n.attribute(forName: "name")?.stringValue ?? ""
                for name in nameList.split(separator: ",") {
                    // XML handles entities like &#9; correctly but minipro returns devices like this "MT28FW512ABA1HPN-0AAT&#9;(RB158)@BGA64"
                    icNames.insert(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(
                            of: "\t", with: "&#9;"))
                    icNames.insert(name.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        return icNames
    }

    public static func run(
        _ result: InvocationResult, infoicPath: URL, programmerModel: ProgrammerModel? = nil
    ) throws -> SupportedDevices {
        try ensureNoError(invocationResult: result)

        let logicICsPath = Bundle.main.url(forResource: "logicic", withExtension: "xml")!
        let logicICs = getICNames(from: try? XMLDocument(contentsOf: logicICsPath))
        let infoicXmlDoc = try? XMLDocument(contentsOf: infoicPath)
        let eepromICs = getICNames(from: infoicXmlDoc)

        // Custom chips have "(custom)" appended to their names:
        // https://gitlab.com/DavidGriffith/minipro/-/blob/master/src/database.c#L516
        let lines = result.stdOutString.components(separatedBy: .newlines).map {
            $0.replacingOccurrences(of: #"\(custom\)"#, with: "", options: .regularExpression)
        }.filter { !$0.isEmpty }

        return SupportedDevices(
            logicICs: getLogicICs(lines, logicICs: logicICs, eepromICs: eepromICs),
            eepromICs: getEepromICs(lines, logicICs: logicICs, eepromICs: eepromICs),
            catalog: chipCatalog(from: infoicXmlDoc, programmerModel: programmerModel))
    }

    /// The manufacturers only matter for the database the connected programmer
    /// actually uses, so the catalog stays empty until the model is known.
    private static func chipCatalog(from xmlDoc: XMLDocument?, programmerModel: ProgrammerModel?)
        -> ChipCatalog
    {
        guard let xmlDoc, let programmerModel else {
            return .empty
        }
        return ChipCatalog.build(
            from: xmlDoc, databaseType: ChipCatalog.databaseType(for: programmerModel))
    }

    private static func getLogicICs(_ lines: [String], logicICs: Set<String>, eepromICs: Set<String>) -> [String] {
        var seen: Set<String> = []
        return
            lines
            .filter { seen.insert($0).inserted }
            .filter { logicICs.contains($0) || !eepromICs.contains($0) }
    }

    private static func getEepromICs(_ lines: [String], logicICs: Set<String>, eepromICs: Set<String>) -> [String] {
        var seen: Set<String> = []
        return
            lines
            .filter { seen.insert($0).inserted }
            .filter { eepromICs.contains($0) || !logicICs.contains($0) }
    }
}
