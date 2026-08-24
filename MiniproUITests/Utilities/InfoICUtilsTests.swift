//
//  InfoICUtilsTests.swift
//  MiniproUITests
//

import Testing
import Foundation

@testable import Visual_Minipro

@Suite(.serialized)
struct InfoICUtilsTests {
    @Test func returnsLegacyInfoICForNonT76WhenToggleEnabled() {
        let original = UserDefaults.standard.useLegacyInfoIC
        defer { UserDefaults.standard.useLegacyInfoIC = original }
        UserDefaults.standard.useLegacyInfoIC = true

        #expect(InfoICUtils.resolveInfoICPath(for: .t48).lastPathComponent == "infoic_0.7.4.xml")
    }

    @Test func returnsDefaultInfoICForT76WhenToggleEnabled() {
        let original = UserDefaults.standard.useLegacyInfoIC
        defer { UserDefaults.standard.useLegacyInfoIC = original }
        UserDefaults.standard.useLegacyInfoIC = true

        #expect(InfoICUtils.resolveInfoICPath(for: .t76).lastPathComponent == "infoic.xml")
    }

    @Test func returnsDefaultInfoICWhenToggleDisabled() {
        let original = UserDefaults.standard.useLegacyInfoIC
        defer { UserDefaults.standard.useLegacyInfoIC = original }
        UserDefaults.standard.useLegacyInfoIC = false

        #expect(InfoICUtils.resolveInfoICPath(for: .t48).lastPathComponent == "infoic.xml")
    }

}

@Suite(.serialized)
struct InstalledSoftwareBundleTests {
    @Test func remembersBundlePerProgrammerModel() {
        let original = UserDefaults.standard.installedSoftwareBundles
        let originalStatuses = UserDefaults.standard.installedSoftwareBundleStatuses
        defer {
            UserDefaults.standard.installedSoftwareBundles = original
            UserDefaults.standard.installedSoftwareBundleStatuses = originalStatuses
        }
        UserDefaults.standard.installedSoftwareBundles = [:]
        UserDefaults.standard.installedSoftwareBundleStatuses = [:]

        UserDefaults.standard.setInstalledSoftwareBundle(
            "xgpro_T76_V1321.rar",
            verificationStatus: .checksumMatch,
            for: .t76
        )
        UserDefaults.standard.setInstalledSoftwareBundle(
            "xgproV1310_T48_T56_T866II_Setup.rar",
            verificationStatus: nil,
            for: .t56
        )

        #expect(
            UserDefaults.standard.installedSoftwareBundle(for: .t76)
                == InstalledSoftwareBundle(fileName: "xgpro_T76_V1321.rar", verificationStatus: .checksumMatch)
        )
        #expect(
            UserDefaults.standard.installedSoftwareBundle(for: .t56)
                == InstalledSoftwareBundle(
                    fileName: "xgproV1310_T48_T56_T866II_Setup.rar",
                    verificationStatus: nil
                )
        )
        #expect(UserDefaults.standard.installedSoftwareBundle(for: .t48) == nil)
    }
}
