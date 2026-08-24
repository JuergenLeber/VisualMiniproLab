//
//  XgproImageUtils.swift
//  Visual Minipro
//

import Foundation
import os

enum XgproImageUtilsError: Error {
    case imagesNotFound
}

struct ChipImage: Identifiable, Equatable, Hashable {
    let id: String
    let caption: String
    let url: URL
}

class XgproImageUtils {
    private static let logger = Logger(
        subsystem: "com.3d-logic.visualminipro",
        category: "XgproImageUtils"
    )

    // minipro reports adapters and ICSP connections as the name of the image
    // Xgpro would show, e.g. "Adapter001.JPG" or "ICP009.JPG". See
    // https://gitlab.com/DavidGriffith/minipro/-/blob/master/src/main.c#L616
    private static let imageReference = /^(Adapter[0-9A-Za-z]+|ICP[0-9]+)\.JPG$/

    private static let imageKeyCaptions = [
        "Package": "Adapter",
        "ICSP": "ICSP connection",
    ]

    public static func resolveImageDirectory(for programmerModel: ProgrammerModel) throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return
            baseDirectory
            .appendingPathComponent(programmerModel.rawValue, isDirectory: true)
            .appendingPathComponent("img", isDirectory: true)
    }

    /// Copies the adapter and ICSP images out of an extracted Xgpro software
    /// bundle. Returns the number of images installed.
    @discardableResult
    public static func installImages(from baseFolder: URL, programmerModel: ProgrammerModel) throws -> Int {
        let sourceFolder = baseFolder.appendingPathComponent("img", isDirectory: true)
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: sourceFolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            logger.notice("No img folder in \(baseFolder.path, privacy: .public)")
            throw XgproImageUtilsError.imagesNotFound
        }

        let images = entries.filter { $0.pathExtension.lowercased() == "jpg" }
        if images.isEmpty {
            logger.notice("No images in \(sourceFolder.path, privacy: .public)")
            throw XgproImageUtilsError.imagesNotFound
        }

        let destinationFolder = try resolveImageDirectory(for: programmerModel)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        for image in images {
            let destination = destinationFolder.appendingPathComponent(image.lastPathComponent)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: image, to: destination)
        }
        logger.notice(
            "Installed \(images.count, privacy: .public) images to \(destinationFolder.path, privacy: .public)"
        )
        return images.count
    }

    /// The images to show for a chip, based on the "Package" and "ICSP" values
    /// reported by minipro. Empty when no software bundle has been installed.
    public static func chipImages(for deviceDetails: DeviceDetails, programmerModel: ProgrammerModel) -> [ChipImage] {
        return deviceDetails.deviceInfo.compactMap { info in
            guard
                let caption = imageKeyCaptions[info.key],
                info.value.contains(imageReference),
                let url = resolveImagePath(for: info.value, programmerModel: programmerModel)
            else {
                return nil
            }
            return ChipImage(id: url.lastPathComponent, caption: caption, url: url)
        }
    }

    public static func resolveImagePath(for reference: String, programmerModel: ProgrammerModel) -> URL? {
        guard let imageDirectory = try? resolveImageDirectory(for: programmerModel) else {
            return nil
        }
        return imageFileNames(for: reference, programmerModel: programmerModel)
            .map { imageDirectory.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Xgpro ships a generic image and per-programmer variants of it, e.g.
    /// ICP009.jpg and T76ICP009.jpg. Prefer the one matching the programmer.
    /// Adapter pictures do not follow that scheme, so they come from the
    /// adapter table Xgpro carries.
    static func imageFileNames(for reference: String, programmerModel: ProgrammerModel) -> [String] {
        guard reference.contains(imageReference) else {
            return []
        }
        if let adapter = XgproAdapterCatalog.adapter(for: reference, programmerModel: programmerModel) {
            return adapter.imageNames
        }
        let name = (reference as NSString).deletingPathExtension
        return ["\(programmerModel.rawValue)\(name).jpg", "\(name).jpg"]
    }
}
