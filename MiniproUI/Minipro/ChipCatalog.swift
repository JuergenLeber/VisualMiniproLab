//
//  ChipCatalog.swift
//  MiniproUI
//

import Foundation
import os

/// A chip as one manufacturer declares it in infoic.xml.
///
/// The same chip name shows up under several manufacturers with different
/// parameters - "M27256@DIP28" is an INTEL part with chip ID 0x8904 and an ST
/// part with 0x2004 - while `minipro -d` always loads the first entry that
/// matches the name. Manufacturers whose entries are identical apart from the
/// name are merged into one variant, so only distinctions that matter reach
/// the chip list.
struct ChipVariant: Hashable, Identifiable {
    let name: String
    let manufacturers: [String]
    let chipId: String?
    let isCustom: Bool
    let databaseType: String
    /// The `<ic .../>` element verbatim from infoic.xml. Only kept for names
    /// more than one variant claims - the rest never need an override.
    let definition: String?
    /// Position among the variants of this name, which is also file order.
    let index: Int

    var id: String { "\(name)#\(index)" }

    var manufacturerLabel: String {
        let label = manufacturers.joined(separator: ", ")
        return isCustom ? "\(label) (custom)" : label
    }

    /// infoic.xml pads every chip ID to 32 bits; datasheets and XGpro spell out
    /// only the significant bytes.
    var formattedChipId: String? {
        guard let chipId else {
            return nil
        }
        let value = chipId.hasPrefix("0x") || chipId.hasPrefix("0X") ? String(chipId.dropFirst(2)) : chipId
        var digits = String(value.drop(while: { $0 == "0" })).uppercased()
        if digits.isEmpty {
            return nil
        }
        if !digits.count.isMultiple(of: 2) {
            digits = "0" + digits
        }
        return "0x" + digits
    }
}

/// The chip names of one programmer's database, each with the manufacturers
/// that declare it.
struct ChipCatalog {
    static let empty = ChipCatalog(variantsByName: [:], sharedSections: "")

    private let variantsByName: [String: [ChipVariant]]
    /// The `<configurations>` and `<maps>` sections of infoic.xml. A chip can
    /// point at a configuration by name, so an override database has to carry
    /// them along.
    let sharedSections: String

    func variants(for name: String) -> [ChipVariant] {
        variantsByName[name] ?? []
    }

    static func databaseType(for programmerModel: ProgrammerModel) -> String {
        switch programmerModel {
        case .tl866A, .tl866CS:
            "INFOIC"
        case .t76:
            "INFOICT76"
        case .tl866IIPlus, .t48, .t56:
            "INFOIC2PLUS"
        }
    }

    static func build(from xmlDoc: XMLDocument, databaseType: String) -> ChipCatalog {
        guard
            let elements = try? xmlDoc.nodes(forXPath: "//database[@type='\(databaseType)']/*/ic")
                as? [XMLElement]
        else {
            return .empty
        }

        var drafts = [String: [VariantDraft]]()
        drafts.reserveCapacity(elements.count * 2)
        for element in elements {
            guard let parent = element.parent as? XMLElement else {
                continue
            }
            let manufacturer = parent.attribute(forName: "name")?.stringValue ?? ""
            let isCustom = parent.name == "custom"
            var signature = ""
            for attribute in element.attributes ?? [] where attribute.name != "name" {
                signature += "\(attribute.name ?? "")=\(attribute.stringValue ?? "");"
            }
            let draft = VariantDraft(
                signature: signature,
                isCustom: isCustom,
                manufacturers: [manufacturer],
                chipId: element.attribute(forName: "chip_id")?.stringValue,
                element: element
            )
            let nameList = element.attribute(forName: "name")?.stringValue ?? ""
            for rawName in nameList.split(separator: ",") {
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                if name.isEmpty {
                    continue
                }
                for key in nameKeys(for: name) {
                    var variants = drafts[key] ?? []
                    if let index = variants.firstIndex(where: {
                        $0.signature == signature && $0.isCustom == isCustom
                    }) {
                        if !variants[index].manufacturers.contains(manufacturer) {
                            variants[index].manufacturers.append(manufacturer)
                        }
                    } else {
                        variants.append(draft)
                    }
                    drafts[key] = variants
                }
            }
        }

        var variantsByName = [String: [ChipVariant]]()
        variantsByName.reserveCapacity(drafts.count)
        for (name, variants) in drafts {
            let isAmbiguous = variants.count > 1
            variantsByName[name] = variants.enumerated().map { index, draft in
                ChipVariant(
                    name: name,
                    manufacturers: draft.manufacturers,
                    chipId: draft.chipId,
                    isCustom: draft.isCustom,
                    databaseType: databaseType,
                    definition: isAmbiguous ? definition(of: draft.element) : nil,
                    index: index
                )
            }
        }

        return ChipCatalog(
            variantsByName: variantsByName,
            sharedSections: sharedSections(of: xmlDoc)
        )
    }

    /// minipro reads the database without resolving entities, so it reports
    /// (and expects) names like "MT28FW512ABA1HPN-0AAT&#9;(RB158)@BGA64" while
    /// `XMLDocument` hands out the resolved tab. Both spellings become keys.
    private static func nameKeys(for name: String) -> [String] {
        let escaped = name.replacingOccurrences(of: "\t", with: "&#9;")
        return escaped == name ? [name] : [name, escaped]
    }

    private static func definition(of element: XMLElement) -> String {
        element.xmlString.replacingOccurrences(of: "\t", with: "&#9;")
    }

    private static func sharedSections(of xmlDoc: XMLDocument) -> String {
        ["configurations", "maps"]
            .compactMap { xmlDoc.rootElement()?.elements(forName: $0).first?.xmlString }
            .joined(separator: "\n")
    }

    private struct VariantDraft {
        let signature: String
        let isCustom: Bool
        var manufacturers: [String]
        let chipId: String?
        let element: XMLElement
    }
}

/// A row of the chip list: the name minipro is invoked with plus the variant it
/// was picked from. A name several manufacturers declare appears once per
/// variant.
struct ChipListItem: Hashable, Identifiable {
    let name: String
    let variant: ChipVariant?

    var id: String { variant?.id ?? name }
    var manufacturerLabel: String? { variant?.manufacturerLabel }

    static func items(for names: [String], catalog: ChipCatalog) -> [ChipListItem] {
        names.flatMap { name -> [ChipListItem] in
            let variants = catalog.variants(for: name)
            if variants.isEmpty {
                return [ChipListItem(name: name, variant: nil)]
            }
            return variants.map { ChipListItem(name: name, variant: $0) }
        }
    }
}

/// minipro has no way to ask for a manufacturer: `-d` loads whichever entry
/// matches the name first. Handing it a database that holds nothing but the
/// chosen entry is what makes the manufacturer selection stick.
enum ChipVariantOverride {
    private static let logger = Logger(category: "ChipVariantOverride")
    private static let fileName = "selected-chip-infoic.xml"

    /// The database to invoke minipro with for `item`: an override for a name
    /// with several variants, `fallback` (the full database) otherwise.
    static func infoicPath(for item: ChipListItem, catalog: ChipCatalog, fallback: URL) -> URL {
        guard let variant = item.variant, let definition = variant.definition else {
            return fallback
        }
        let wrapper = variant.isCustom ? "custom" : "manufacturer"
        let manufacturer = escape(variant.manufacturers.first ?? "")
        let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <infoic>
              <database type="\(variant.databaseType)">
                <\(wrapper) name="\(manufacturer)">
                  \(definition)
                </\(wrapper)>
              </database>
            \(catalog.sharedSections)
            </infoic>
            """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try Data(xml.utf8).write(to: url, options: .atomic)
            return url
        } catch {
            logger.error(
                "Could not write the chip database override: \(error.localizedDescription, privacy: .public)")
            return fallback
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
