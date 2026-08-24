//
//  UserDefaultsExtensions.swift
//  Visual Minipro
//
//  Created by Pawel Kadluczka on 10/26/25.
//

import Foundation

struct InstalledSoftwareBundle: Equatable {
    let fileName: String
    let verificationStatus: SoftwareBundleVerificationStatus?
}

extension UserDefaults {
    private static let favoriteChipsKey = "favoriteChips"
    private static let libusbDebugLoggingKey = "libusbDebugLogging"
    private static let useLegacyInfoICKey = "useLegacyInfoIC"
    private static let installedSoftwareBundlesKey = "installedSoftwareBundles"
    private static let installedSoftwareBundleStatusesKey = "installedSoftwareBundleStatuses"

    var favoriteChips: [String] {
        get { stringArray(forKey: UserDefaults.favoriteChipsKey) ?? [] }
        set { set(newValue, forKey: UserDefaults.favoriteChipsKey)}
    }

    var libusbDebugLogging: Bool {
        get { bool(forKey: UserDefaults.libusbDebugLoggingKey) }
        set { set(newValue, forKey: UserDefaults.libusbDebugLoggingKey) }
    }

    var useLegacyInfoIC: Bool {
        get { bool(forKey: UserDefaults.useLegacyInfoICKey) }
        set { set(newValue, forKey: UserDefaults.useLegacyInfoICKey) }
    }

    var installedSoftwareBundles: [String: String] {
        get { dictionary(forKey: UserDefaults.installedSoftwareBundlesKey) as? [String: String] ?? [:] }
        set { set(newValue, forKey: UserDefaults.installedSoftwareBundlesKey) }
    }

    var installedSoftwareBundleStatuses: [String: String] {
        get { dictionary(forKey: UserDefaults.installedSoftwareBundleStatusesKey) as? [String: String] ?? [:] }
        set { set(newValue, forKey: UserDefaults.installedSoftwareBundleStatusesKey) }
    }

    func installedSoftwareBundle(for programmerModel: ProgrammerModel) -> InstalledSoftwareBundle? {
        guard let fileName = installedSoftwareBundles[programmerModel.rawValue] else {
            return nil
        }
        return InstalledSoftwareBundle(
            fileName: fileName,
            verificationStatus: installedSoftwareBundleStatuses[programmerModel.rawValue].flatMap {
                SoftwareBundleVerificationStatus(rawValue: $0)
            }
        )
    }

    func setInstalledSoftwareBundle(
        _ fileName: String,
        verificationStatus: SoftwareBundleVerificationStatus?,
        for programmerModel: ProgrammerModel
    ) {
        installedSoftwareBundles[programmerModel.rawValue] = fileName
        installedSoftwareBundleStatuses[programmerModel.rawValue] = verificationStatus?.rawValue
    }
}
