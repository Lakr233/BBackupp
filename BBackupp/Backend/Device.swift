//
//  Device.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import AnyCodable
import AppleMobileDevice
import Combine
import Foundation

class Device: ObservableObject, Codable, Equatable, Hashable, Identifiable {
    public typealias DevcieID = String

    var id: DevcieID { universalDeviceIdentifier }
    var udid: DevcieID { universalDeviceIdentifier }

    // MARK: - STORED PROPERTY -

    let universalDeviceIdentifier: DevcieID
    var deviceRecord: AppleMobileDeviceManager.DeviceRecord? {
        didSet { notifyChange() }
    }

    var pairRecord: AppleMobileDeviceManager.PairRecord? {
        didSet { notifyChange() }
    }

    var extra: Extra = .init() {
        didSet { notifyChange() }
    }

    var config: Configuration {
        didSet { notifyChange() }
    }

    // MARK: - STORED PROPERTY -

    var deviceName: String { deviceRecord?.deviceName ?? "Unknown" }
    var deviceSystemIcon: String {
        deviceRecord?.deviceClass?.lowercased() ?? "questionmark.circle"
    }

    init(udid: String) {
        universalDeviceIdentifier = udid
        if let config = appConfiguration.deviceConfiguration[udid] {
            self.config = config
        } else {
            config = .init(universalDeviceIdentifier: universalDeviceIdentifier)
            appConfiguration.deviceConfiguration[udid] = config
        }
        assert(config.universalDeviceIdentifier == universalDeviceIdentifier)
        config.prepareDeafultBackupDirIfNeeded()
    }

    func notifyChange() {
        objectWillChange.send()
        appConfiguration.deviceConfiguration[universalDeviceIdentifier] = config
        appConfiguration.save()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(universalDeviceIdentifier)
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        true &&
            lhs.universalDeviceIdentifier == rhs.universalDeviceIdentifier &&
            lhs.deviceRecord == rhs.deviceRecord &&
            lhs.pairRecord == rhs.pairRecord &&
            lhs.extra == rhs.extra
    }
}

extension Device {
    struct Extra: Codable, Equatable {
        var isPaired: Bool = false
        var isWirelessConnectionEnabled: Bool = false
        var isBackupEncryptionEnabled: Bool = false
    }
}

extension Device {
    struct Configuration: Codable, Equatable {
        let universalDeviceIdentifier: DevcieID
        init(universalDeviceIdentifier: DevcieID) {
            self.universalDeviceIdentifier = universalDeviceIdentifier
        }

        var automaticBackupEnabled: Bool = false
        var wirelessBackupEnabled: Bool = true
        var requiresCharging: Bool = true

        var automaticBackupOnMonday: Bool = true
        var automaticBackupOnTuesday: Bool = true
        var automaticBackupOnWednesday: Bool = true
        var automaticBackupOnThursday: Bool = true
        var automaticBackupOnFriday: Bool = true
        var automaticBackupOnSaturday: Bool = true
        var automaticBackupOnSunday: Bool = true

        var backupKeepOption: BackupKeepOption = .d7

        var customizedBackupTimeRangeEnabled: Bool = false
        // from 20:00 -> next day 6:00 as default
        var customizedBackupFrom: Int = 20 * 3600
        var customizedBackupTo: Int = 6 * 3600

        var backupMonitorDescription: String {
            [
                String(backupMonitorFrom / 3600).paddingInt(len: 2),
                ":",
                String((backupMonitorFrom % 3600) / 60).paddingInt(len: 2),
                " -> ",
                String(backupMonitorTo / 3600).paddingInt(len: 2),
                ":",
                String((backupMonitorTo % 3600) / 60).paddingInt(len: 2),
                backupMonitorTo < backupMonitorFrom ? " (next day)" : "",
            ]
            .joined()
        }

        var backupLocation: String? = nil

        var notificationSendProgressPercent: Bool = true
        var notificationProvider: NotificationProvider = .none {
            didSet { if oldValue != notificationProvider {
                notificationProviderConfig = [:]
            } }
        }

        var notificationEnabled: Bool = true
        var notificationProviderConfig: NotificationConfig = .init()
    }
}

extension Device.Configuration {
    var backupMonitorFrom: Int {
        if customizedBackupTimeRangeEnabled { return customizedBackupFrom }
        return appConfiguration.defaultMonitoringRangeFrom
    }

    var backupMonitorTo: Int {
        if customizedBackupTimeRangeEnabled { return customizedBackupTo }
        return appConfiguration.defaultMonitoringRangeTo
    }

    var defaultBackupDirName: String {
        "Backup_\(universalDeviceIdentifier)"
    }

    var defaultBackupUrl: URL {
        appConfiguration
            .defaultBackupLocationUrl
            .appendingPathComponent(defaultBackupDirName)
    }

    var storeLocationURL: URL {
        if let backupLocation {
            return URL(fileURLWithPath: backupLocation)
        } else {
            return defaultBackupUrl
        }
    }

    var deviceIdRecordURL: URL {
        storeLocationURL
            .appendingPathComponent("DeviceID")
            .appendingPathExtension("txt")
    }

    var incrementalCacheUrl: URL {
        storeLocationURL.appendingPathComponent("IncrementalCache")
    }

    var inProgressUrl: URL {
        storeLocationURL
            .appendingPathComponent("InProgress")
    }

    /// Only call this function when setting up backup dir by user at right time
    /// - Parameter atLocation: where to store, nil = default
    func setupDir(atLocation: URL?) {
        let targetLocation = atLocation ?? defaultBackupUrl

        try? FileManager.default.createDirectory(
            at: targetLocation,
            withIntermediateDirectories: true
        )

        /*
         This signal file serves a crucial purpose – it's generated upon directory selection.

         In the event that this marker file goes missing unexpectedly,
         it's quite probable that the target folder hasn't been properly mounted
         (perhaps due to unavailable network devices).

         This situation could lead to backups being erroneously written to the
         wrong device.

         As a result, the entire subsequent backup process would be automatically canceled.
         */

        try? universalDeviceIdentifier.write(
            to: deviceIdRecordURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func prepareDeafultBackupDirIfNeeded() {
        guard backupLocation == nil else { return }
        setupDir(atLocation: defaultBackupUrl)
    }
}

extension Device.Configuration {
    enum BackupKeepOption: Int, CaseIterable, Codable, Identifiable {
        var id: Int { rawValue }

//        case defaultToApp = -1

        case unlimited = 0

        case n1
        case n2
        case n3
        case n4
        case n5
        case n6
        case n7

        case d3
        case d7
        case d30
        case d365

        var interfaceText: String {
            switch self {
//            case .defaultToApp: return "Keep Unspecified (use default value)"
            case .unlimited: return "Keep Unlimited Backups"

            case .n1: return "Keep 1 Backups"
            case .n2: return "Keep 2 Backups"
            case .n3: return "Keep 3 Backups"
            case .n4: return "Keep 4 Backups"
            case .n5: return "Keep 5 Backups"
            case .n6: return "Keep 6 Backups"
            case .n7: return "Keep 7 Backups"

            case .d3: return "Keep All within 3 Days"
            case .d7: return "Keep All within 7 Days"
            case .d30: return "Keep All within 30 Days"
            case .d365: return "Keep All within 365 Days"
            }
        }
    }

    enum NotificationProvider: String, CaseIterable, Codable, Identifiable {
        var id: String { rawValue }
        case none
        case bark

        var interfaceText: String {
            switch self {
            case .none: return "None"
            case .bark: return "Bark"
            }
        }

        var descriptionText: String {
            switch self {
            case .none: return "You will not receive backup related notification on your devices."
            case .bark: return "Bark is an iOS App which allows you to push custom notifications to your iPhone."
            }
        }
    }

    typealias NotificationConfig = [String: String]
}

extension Device.Configuration {
    enum PushNotificationError: Error {
        case missingRequiredInfo
        case invalidValue
        case unsupported
    }

    func push(message: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard notificationEnabled else { return }
        switch notificationProvider {
        case .none:
            completion?(.failure(PushNotificationError.unsupported))
            return
        case .bark:
            let notificationConfig = notificationProviderConfig
            let barkNotificationGroup = notificationConfig["group"]
            let barkNotificationAvatar = notificationConfig["icon"]
            let barkNotificationSound = notificationConfig["sound"]
            guard var endpoint: String = notificationConfig["endpoint"] else {
                completion?(.failure(PushNotificationError.missingRequiredInfo))
                return
            }
            while endpoint.hasSuffix("/") {
                endpoint.removeLast()
            }
            endpoint += "/\(Constants.appName)/\(message)"
            var comps = URLComponents(string: endpoint)
            comps?.queryItems = [
                "group": barkNotificationGroup,
                "icon": barkNotificationAvatar,
                "sound": barkNotificationSound,
            ]
            .compactMap {
                if $0.value == nil { return nil }
                return URLQueryItem(name: $0.key, value: $0.value)
            }
            guard let finalUrl = comps?.url else {
                completion?(.failure(PushNotificationError.invalidValue))
                return
            }
            let request = URLRequest(url: finalUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
            URLSession.shared.dataTask(with: request) { _, _, error in
                if let error {
                    completion?(.failure(error))
                } else {
                    completion?(.success())
                }
            }.resume()
        }
    }
}

extension Device.Configuration {
    func walkthroughAndReturnBackupThatIsNoLongerNeeded(backups: [Backup]) -> [Backup.ID] {
        let backups = backups.filter { !$0.keep } // don't get that in count

        var limitNumber = 65535
        switch backupKeepOption {
        case .unlimited: return []

        case .d3: return backups.filter { Date().days(from: $0.archivedAt) > 3 }.map(\.id)
        case .d7: return backups.filter { Date().days(from: $0.archivedAt) > 7 }.map(\.id)
        case .d30: return backups.filter { Date().days(from: $0.archivedAt) > 30 }.map(\.id)
        case .d365: return backups.filter { Date().days(from: $0.archivedAt) > 365 }.map(\.id)

        case .n1: limitNumber = 1
        case .n2: limitNumber = 2
        case .n3: limitNumber = 3
        case .n4: limitNumber = 4
        case .n5: limitNumber = 5
        case .n6: limitNumber = 6
        case .n7: limitNumber = 7
        }
        var deleter = backups.sorted { $0.archivedAt < $1.archivedAt }
        var ret = [Backup.ID]()
        while deleter.count > limitNumber, !deleter.isEmpty {
            ret.append(deleter.removeFirst().id)
        }
        return ret
    }

    enum SkipBackupReason: LocalizedError {
        case targetDirectoryNotWritable
        case targetDirectoryDeviceIDMismatch
        case invalidConfig
        case notEnabled
        case requiresChargingButNot
        case notInMonitorDateRange
        case notInEnabledDayOfTheWeek
    }

    func needsBackup(udid: String) -> Result<Void, SkipBackupReason> {
        guard automaticBackupEnabled else { return .failure(.notEnabled) }

        var isDir = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: storeLocationURL.path, isDirectory: &isDir),
              isDir.boolValue
        else {
            return .failure(.targetDirectoryNotWritable)
        }

        guard let str = try? String(contentsOf: deviceIdRecordURL),
              str.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == udid.lowercased()
        else {
            return .failure(.targetDirectoryDeviceIDMismatch)
        }

        if requiresCharging {
            guard let batteryInfo = appleDevice.obtainDeviceBatteryInfo(udid: udid),
                  (batteryInfo.batteryIsCharging ?? false) || (batteryInfo.externalConnected ?? false)
            else { return .failure(.requiresChargingButNot) }
        }
        let currentDate = Int(Date().timeIntervalSince1970)
        let cal = Calendar.current

        let startOfTheDay = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        let dateOffset = currentDate - startOfTheDay

        if false {}
        if backupMonitorFrom == backupMonitorTo { return .failure(.invalidConfig) } // misconfigured, not my bad
        if backupMonitorFrom < backupMonitorTo, // same day
           backupMonitorFrom < dateOffset, dateOffset < backupMonitorTo // in between
        { /* go on */ }
        else if backupMonitorFrom > backupMonitorTo, // cross the day
                dateOffset > backupMonitorFrom || // later then from OR
                dateOffset < backupMonitorTo // earlier then next day to
        { /* go on */ }
        else { return .failure(.notInMonitorDateRange) }
        // good, now we passed the day check

        let weekday = cal.component(.weekday, from: Date())
        switch weekday {
        case 1: if !automaticBackupOnSunday { return .failure(.notInMonitorDateRange) }
        case 2: if !automaticBackupOnMonday { return .failure(.notInMonitorDateRange) }
        case 3: if !automaticBackupOnTuesday { return .failure(.notInMonitorDateRange) }
        case 4: if !automaticBackupOnWednesday { return .failure(.notInMonitorDateRange) }
        case 5: if !automaticBackupOnThursday { return .failure(.notInMonitorDateRange) }
        case 6: if !automaticBackupOnFriday { return .failure(.notInMonitorDateRange) }
        case 7: if !automaticBackupOnSaturday { return .failure(.notInMonitorDateRange) }
        default:
            assertionFailure()
            return .failure(.invalidConfig)
        }

        return .success()
    }
}
