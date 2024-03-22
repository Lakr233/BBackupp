//
//  BackupPlan.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import BetterCodable
import Combine
import Foundation

class BackupPlan: ObservableObject, Codable, CopyableCodable, Identifiable {
    var id: UUID = .init()

    let name: String
    let deviceID: Device.ID
    let resticRepo: ResticRepo

    struct Restic: Codable, DefaultCodableStrategy {
        static var defaultValue = Restic()

        var enableChangeDetection: Bool = true
    }

    @DefaultCodable<Restic> var restic: Restic = .init() {
        didSet { objectWillChange.send() }
    }

    struct Automation: Codable, DefaultCodableStrategy {
        static var defaultValue = Automation()

        var enabled: Bool = false
        var deviceWirelessConnectionEnabled: Bool = true
        var deviceRequiresCharging: Bool = true

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
    }

    @DefaultCodable<Automation> var automation: Automation = .init() {
        didSet { objectWillChange.send() }
    }

    struct Notification: Codable, DefaultCodableStrategy {
        static var defaultValue = Notification()

        var enabled: Bool = true
        var sendProgressPercent: Bool = true

        enum Provider: String, Codable, CaseIterable {
            case none
            case bark
            case telegram
        }

        var provider: Provider = .none
        var provoderContext: [String: String] = [:]
    }

    @DefaultCodable<Notification> var notification: Notification = .init() {
        didSet { objectWillChange.send() }
    }

    struct AppStoreConnect: Codable, DefaultCodableStrategy {
        static var defaultValue = AppStoreConnect()

        var enabled: Bool = false
        var ignoreFailure: Bool = false
    }

    @DefaultCodable<AppStoreConnect> var appStoreConnect: AppStoreConnect = .init() {
        didSet { objectWillChange.send() }
    }

    struct Analyzer: Codable, DefaultCodableStrategy {
        static var defaultValue = Analyzer()

        var enabled: Bool = false
        var backupPassword: String = ""
        struct BinaryExecutor: Codable, Identifiable {
            var id: UUID = .init()
            var name: String = ""
            var enabled: Bool = false
        }

        var binaryExecutors: [BinaryExecutor] = []
    }

    @DefaultCodable<Analyzer> var analyzer: Analyzer = .init() {
        didSet { objectWillChange.send() }
    }

    init(name: String, deviceID: Device.ID, resticRepo: ResticRepo) {
        self.name = name
        self.deviceID = deviceID
        self.resticRepo = resticRepo
    }
}

extension BackupPlan.Automation {
    var backupMonitorFrom: Int {
        if customizedBackupTimeRangeEnabled { return customizedBackupFrom }
        return appSetting.defaultMonitoringRangeFrom
    }

    var backupMonitorTo: Int {
        if customizedBackupTimeRangeEnabled { return customizedBackupTo }
        return appSetting.defaultMonitoringRangeTo
    }

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

    enum BackupKeepOption: Int, CaseIterable, Codable, Identifiable {
        var id: Int { rawValue }
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
    }
}

extension BackupPlan.Automation.BackupKeepOption {
    var interfaceText: String {
        switch self {
        case .unlimited: "Keep Unlimited Backups"

        case .n1: "Keep 1 Backups"
        case .n2: "Keep 2 Backups"
        case .n3: "Keep 3 Backups"
        case .n4: "Keep 4 Backups"
        case .n5: "Keep 5 Backups"
        case .n6: "Keep 6 Backups"
        case .n7: "Keep 7 Backups"

        case .d3: "Keep All within 3 Days"
        case .d7: "Keep All within 7 Days"
        case .d30: "Keep All within 30 Days"
        case .d365: "Keep All within 365 Days"
        }
    }

    func examSnapshotsReturnRemoving(_ list: [ResticRepo.Snapshot]) -> [ResticRepo.Snapshot.ID] {
        var saveList = list.sorted { lhs, rhs in
            lhs.date > rhs.date
        }

        func saveFirst(_ n: Int) {
            guard saveList.count > n else { return }
            saveList = Array(saveList[0 ..< n])
        }

        switch self {
        case .unlimited: break

        case .n1: saveFirst(1)
        case .n2: saveFirst(2)
        case .n3: saveFirst(3)
        case .n4: saveFirst(4)
        case .n5: saveFirst(5)
        case .n6: saveFirst(6)
        case .n7: saveFirst(7)

        case .d3: saveList = saveList.filter { abs($0.date.timeIntervalSinceNow) < 3 * 24 * 3600 }
        case .d7: saveList = saveList.filter { abs($0.date.timeIntervalSinceNow) < 7 * 24 * 3600 }
        case .d30: saveList = saveList.filter { abs($0.date.timeIntervalSinceNow) < 30 * 24 * 3600 }
        case .d365: saveList = saveList.filter { abs($0.date.timeIntervalSinceNow) < 365 * 24 * 3600 }
        }

        let saveListIDs = Set(saveList.map(\.id))
        let removeList = Set(list.map(\.id)).subtracting(saveListIDs)
        return Array(removeList)
    }
}

extension BackupPlan.Notification {
    enum PushError: Error {
        case invlidConfig
        case network
        case unknown
    }

    func send(message: String, completion: @escaping (Result<Void, PushError>) -> Void) {
        guard enabled else { return }
        switch provider {
        case .none:
            completion(.failure(.invlidConfig))
        case .bark:
            sendBark(message: message, completion: completion)
        case .telegram:
            sendTelegram(message: message, completion: completion)
        }
    }

    func sendBark(message: String, completion: @escaping (Result<Void, PushError>) -> Void) {
        guard var endpoint = provoderContext["BarkEndpoint"] else {
            completion(.failure(.invlidConfig))
            return
        }
        while endpoint.hasSuffix("/") {
            endpoint.removeLast()
        }
        endpoint += "/\(Constants.appName)/\(message)"
        var comps = URLComponents(string: endpoint)
        comps?.queryItems = [
            "group": provoderContext["BarkGroup"],
            "icon": provoderContext["BarkIcon"],
            "sound": provoderContext["BarkSound"],
        ]
        .compactMap {
            if $0.value == nil { return nil }
            return URLQueryItem(name: $0.key, value: $0.value)
        }
        guard let finalUrl = comps?.url else {
            completion(.failure(.invlidConfig))
            return
        }
        let request = URLRequest(url: finalUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                completion(.failure(.network))
            } else {
                completion(.success())
            }
        }.resume()
    }

    func sendTelegram(message: String, completion: @escaping (Result<Void, PushError>) -> Void) {
        guard let token = provoderContext["TelegramBotToken"],
              let chatID = provoderContext["TelegramBotChatID"]
        else {
            completion(.failure(.invlidConfig))
            return
        }
        let endpoint = "https://api.telegram.org/bot\(token)/sendMessage?chat_id=\(chatID)"
        guard let url = URL(string: endpoint) else {
            completion(.failure(.invlidConfig))
            return
        }
        var request = URLRequest(url: url)
        struct PostBody: Codable {
            var chat_id: String
            var text: String
        }
        let body = PostBody(chat_id: chatID, text: message)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                completion(.failure(.network))
            } else {
                completion(.success())
            }
        }.resume()
    }
}

extension BackupPlan.Notification.Provider {
    var interfaceText: String {
        switch self {
        case .none: "None"
        case .bark: "Bark"
        case .telegram: "Telegram"
        }
    }
}

extension BackupPlan.Notification.PushError {
    var interfaceText: String {
        switch self {
        case .invlidConfig: "Invalid Configuration"
        case .network: "Network Error"
        case .unknown: "Unknown Error"
        }
    }
}

extension BackupPlan {
    func needsBackup(record _: AppleMobileDeviceManager.DeviceRecord) -> Bool {
        guard automation.enabled else {
            print("[*] \(id) automation is not enabled for device \(deviceID) ")
            return false
        }

        if automation.deviceRequiresCharging {
            guard let batteryInfo = amdManager.obtainDeviceBatteryInfo(udid: deviceID),
                  (batteryInfo.batteryIsCharging ?? false) || (batteryInfo.externalConnected ?? false)
            else {
                print("[*] \(id) device \(deviceID) is not charging, skip backup")
                return false
            }
        }

        let currentDate = Int(Date().timeIntervalSince1970)
        let cal = Calendar.current

        let startOfTheDay = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        let dateOffset = currentDate - startOfTheDay

        if false {}
        if automation.backupMonitorFrom == automation.backupMonitorTo {
            print("[*] \(id) backup monitor is misconfigured, skip backup")
            return false
        } // misconfigured, not my bad

        if automation.backupMonitorFrom < automation.backupMonitorTo, // same day
           automation.backupMonitorFrom < dateOffset, dateOffset < automation.backupMonitorTo // in between
        { /* go on */ }
        else if automation.backupMonitorFrom > automation.backupMonitorTo, // cross the day
                dateOffset > automation.backupMonitorFrom || // later then from OR
                dateOffset < automation.backupMonitorTo // earlier then next day to
        { /* go on */ }
        else { return false }

        // good, now we passed the day check
        let weekday = cal.component(.weekday, from: Date())
        switch weekday {
        case 1: if !automation.automaticBackupOnSunday { return false }
        case 2: if !automation.automaticBackupOnMonday { return false }
        case 3: if !automation.automaticBackupOnTuesday { return false }
        case 4: if !automation.automaticBackupOnWednesday { return false }
        case 5: if !automation.automaticBackupOnThursday { return false }
        case 6: if !automation.automaticBackupOnFriday { return false }
        case 7: if !automation.automaticBackupOnSaturday { return false }
        default:
            assertionFailure()
            return false
        }

        return true
    }
}
