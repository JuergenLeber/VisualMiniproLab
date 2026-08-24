//
//  XgproImageUtilsTests.swift
//  MiniproUITests
//

import Foundation
import Testing

@testable import Visual_Minipro

struct XgproImageUtilsTests {
    @Test func prefersProgrammerSpecificImage() {
        #expect(
            XgproImageUtils.imageFileNames(for: "ICP009.JPG", programmerModel: .t76)
                == ["T76ICP009.jpg", "ICP009.jpg"]
        )
    }

    @Test func resolvesAdapterImageFromTheCatalog() {
        // Xgpro's own table: adapter 1 is Adapter001.jpg, T56T48.jpg, T48T48.jpg.
        #expect(
            XgproImageUtils.imageFileNames(for: "Adapter001.JPG", programmerModel: .t56)
                == ["T56T48.jpg", "Adapter001.jpg"]
        )
        #expect(
            XgproImageUtils.imageFileNames(for: "Adapter001.JPG", programmerModel: .t76)
                == ["Adapter001.jpg"]
        )
    }

    @Test func neverResolvesAPictureOfAnotherProgrammer() {
        // Adapter 13 only has T86/T56/T48 pictures, none of them a T76 one.
        #expect(XgproImageUtils.imageFileNames(for: "Adapter013.JPG", programmerModel: .t76) == [])
        #expect(
            XgproImageUtils.imageFileNames(for: "Adapter013.JPG", programmerModel: .t48)
                == ["T48T32A.jpg"]
        )
    }

    @Test func resolvesAdaptersWhoseImageIsNotNumbered() {
        // Adapter 11 ships as AdapterT56.jpg, with a T76 specific picture.
        #expect(
            XgproImageUtils.imageFileNames(for: "Adapter011.JPG", programmerModel: .t76)
                == ["T76T56.jpg", "AdapterT56.jpg"]
        )
    }

    @Test(arguments: ["DIP28", "PLCC44", "ICSP only", "", "Adapter001.png"])
    func ignoresValuesThatAreNotImages(value: String) {
        #expect(XgproImageUtils.imageFileNames(for: value, programmerModel: .t76).isEmpty)
    }

    @Test func chipImagesAreEmptyWhenNoBundleIsInstalled() throws {
        let imageDirectory = try XgproImageUtils.resolveImageDirectory(for: .t76)
        try #require(!FileManager.default.fileExists(atPath: imageDirectory.appendingPathComponent("Adapter999.jpg").path))

        let deviceDetails = DeviceDetails(
            name: "AC39LV088@TSOP48",
            deviceInfo: [
                KeyValuePair(key: "Name", value: "AC39LV088@TSOP48"),
                KeyValuePair(key: "Package", value: "Adapter999.JPG"),
            ],
            programmingInfo: [],
            isLogicChip: false
        )

        #expect(XgproImageUtils.chipImages(for: deviceDetails, programmerModel: .t76).isEmpty)
    }

    @Test func chipImagesResolveInstalledImages() throws {
        let imageDirectory = try XgproImageUtils.resolveImageDirectory(for: .t48)
        let bundleFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("xgpro-images-\(UUID().uuidString)", isDirectory: true)
        let sourceFolder = bundleFolder.appendingPathComponent("img", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: bundleFolder)
            try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent("T48ICP009.jpg"))
            try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent("ICP009.jpg"))
            try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent("notes.txt"))
        }
        try Data("generic".utf8).write(to: sourceFolder.appendingPathComponent("ICP009.jpg"))
        try Data("t48".utf8).write(to: sourceFolder.appendingPathComponent("T48ICP009.jpg"))
        try Data("ignored".utf8).write(to: sourceFolder.appendingPathComponent("notes.txt"))

        #expect(try XgproImageUtils.installImages(from: bundleFolder, programmerModel: .t48) == 2)

        let deviceDetails = DeviceDetails(
            name: "ACE25AC512G@SON8",
            deviceInfo: [
                KeyValuePair(key: "Name", value: "ACE25AC512G@SON8"),
                KeyValuePair(key: "Package", value: "DIP8"),
                KeyValuePair(key: "ICSP", value: "ICP009.JPG"),
            ],
            programmingInfo: [],
            isLogicChip: false
        )

        let chipImages = XgproImageUtils.chipImages(for: deviceDetails, programmerModel: .t48)
        #expect(chipImages.count == 1)
        #expect(chipImages.first?.id == "T48ICP009.jpg")
        #expect(chipImages.first?.caption == "ICSP connection")
    }

    @Test func installImagesThrowsWhenBundleHasNoImages() throws {
        let bundleFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("xgpro-images-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleFolder) }

        #expect(throws: XgproImageUtilsError.self) {
            try XgproImageUtils.installImages(from: bundleFolder, programmerModel: .t76)
        }
    }
}
