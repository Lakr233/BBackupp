//
//  BackupSession.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import AnyCodable
import AppKit
import AppleMobileDevice
import Combine
import Security
import ZipArchive

class BackupSession: NSObject, ObservableObject, Identifiable {
    var id: UUID = .init()
    let device: Device
    let cratedAt: Date
    let targetLocation: URL
    let fullBackupMode: Bool
    var thread: Thread?

    @Published var isRunning: Bool = false
    @Published var progress: Progress = .init()
    @Published var currentProgress: Progress = .init()
    @Published var progressText: String = ""
    @Published var completedAt: Date? = nil
    @Published var errors: [Error] = []
    @Published var logs: [BackupLog] = []

    let progressSender = PassthroughSubject<Progress, Never>()
    var cancellable: Set<AnyCancellable> = []

    // if user cancelled this backup
    // we pick the request up at the nearest checkpoint
    // and perform a cleanup for graceful shutdown
    var cancelled = false {
        didSet { DispatchQueue.main.async { self.objectWillChange.send() } }
    }

    private var lastProgressSent: Int = -65535 // for first progress to display 0%

    init(device: Device, fullBackupMode: Bool) {
        let date = Date()
        self.device = device
        cratedAt = date
        targetLocation = device.config.inProgressUrl // temp url for worker
            .appendingPathComponent(String(Int(date.timeIntervalSince1970 * 1000)))
        self.fullBackupMode = fullBackupMode
        super.init()

        progressSender
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.global(), latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.progress = value
            }
            .store(in: &cancellable)
    }

    func startBackupRoutine() {
        let thread = Thread {
            self.startBackupExec()
            self.thread = nil
        }
        self.thread = thread
        thread.start()
    }

    enum BackupError: Error {
        case targetLocationAlreadyExists
        case unableToWriteManifest
    }

    private func startBackupExec() {
        assert(!Thread.isMainThread)
        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            self.isRunning = true
        })
        log("Backup started")
        log(">>> \(targetLocation.path)")
        device.config.push(message: [
            "A backup request was initialized.",
            "Please get prepared to grant permission if prompted for passcode. Backup encryption is \(device.extra.isBackupEncryptionEnabled ? "enabled" : "disabled").",
        ].joined(separator: "\n"))
        sleep(3)
        let connection: AppleMobileDeviceManager.ConnectionMethod = device.config.wirelessBackupEnabled
            ? .usbPreferred
            : .usb
        log("Initializing connection with \(connection.textDescription)")
        log("Backup mode set to \(fullBackupMode ? "Force Full Backup" : "Prefers Incremental")")
        try? FileManager.default.createDirectory(at: targetLocation, withIntermediateDirectories: true)

        let realBackupDir = targetLocation
            .appendingPathComponent(device.universalDeviceIdentifier)
        if !fullBackupMode, FileManager.default.fileExists(atPath: device.config.incrementalCacheUrl.path) {
            // move cache to our dir if possible
            do {
                log("Preparing incremental backup...")
                try FileManager.default.moveItem(at: device.config.incrementalCacheUrl, to: realBackupDir)
            } catch {
                log("Failed to retrieve required information, use Full Backup Mode instead. \(error) \(error.localizedDescription)", level: .warning)
            }
        }

        log("Sending backup request")
        appleDevice.createBackup(
            udid: device.universalDeviceIdentifier,
            delegate: self,
            connection: connection
        )

        if errors.isEmpty {
            device.config.push(message: [
                "Started Archiving Your Backup 🎉",
                "You can now disconnect your device safely, we will let you know when it's done.",
            ].joined(separator: "\n"))
        }

        do {
            let infoPlist = targetLocation
                .appendingPathComponent("Info")
                .appendingPathExtension("plist")
            let targetInfoLocation = realBackupDir
                .appendingPathComponent("Info")
                .appendingPathExtension("plist")
            if FileManager.default.fileExists(atPath: targetInfoLocation.path) {
                try FileManager.default.removeItem(at: targetInfoLocation)
            }
            try FileManager.default.moveItem(at: infoPlist, to: targetInfoLocation)
        } catch {
            generalFailure(error: error)
        }

        let readMe =
            """
            The directory named with your device identifier (UDID) is your backup.
            Your backup can be recognized by iTunes or Finder to restore your device.

            Type following command in Terminal.app will show the system backup directory
                open "$HOME/Library/Application Support/MobileSync/Backup"

            Or press Command + Shift + G in Finder and paste following line with a enter
                ~/Library/Application Support/MobileSync/Backup

            Once you need to restore:
                - Copy folder printed as "Backup Location"
                - Let iTunes or Finder do the restore work

            Device Identifier: \(device.universalDeviceIdentifier)
            Backup Location: \(realBackupDir.path)
            \(Constants.appName) Version: \(Constants.appVersion) \(Constants.appBuildVersion)
            Backup Encryption: \(device.extra.isBackupEncryptionEnabled)
            Backup Begin Date: \(cratedAt.formatted())
            Backup Complete Date: \(Date().formatted())
            Backup Errors: \(errors.isEmpty ? "None" : errors.map(\.localizedDescription).joined(separator: ", "))
            """
        try? readMe.write(
            to: targetLocation
                .appendingPathComponent("ReadMe")
                .appendingPathExtension("txt"),
            atomically: true,
            encoding: .utf8
        )

        do {
            if errors.isEmpty { try archiveBackup() }
        } catch {
            let prevSuccess = errors.isEmpty
            generalFailure(error: error)
            if prevSuccess {
                device.config.push(message: [
                    "Archive Error",
                    "An archiving backup error occurred, though prior operations succeeded. Intermediate artifacts could be retained until the next backup.",
                ].joined(separator: "\n"))
            }
        }

        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            self.isRunning = false
            self.progress = Progress(totalUnitCount: 100)
            self.progress.completedUnitCount = 100
        })
        log("Backup finished")

        if errors.isEmpty {
            device.config.push(message: "Backup Completed 🎉")
        } else {
            var presentError = errors
            if errors.count > 1 {
                presentError = presentError.filter {
                    if case AppleMobileDeviceBackup.BackupError.cancelled = $0 {
                        return false
                    }
                    return true
                }
            }
            let errText = presentError.map(\.localizedDescription)
                .joined(separator: ", ")
            device.config.push(message: "Backup Completed with Error(s)\n\(errText)")
        }
    }

    private func archiveBackup() throws {
        let uuid = UUID().uuidString
        let zipArchiveLocation = targetLocation
            .appendingPathComponent("Artifacts-\(uuid)")
            .appendingPathExtension("zip")

        log("Creating archive at \(zipArchiveLocation.path)...")
        SSZipArchive.createZipFile(
            atPath: zipArchiveLocation.path,
            withContentsOfDirectory: targetLocation.path,
            keepParentDirectory: false,
            compressionLevel: Int32(0), // Z_NO_COMPRESSION
            password: nil,
            aes: false
        ) { completed, total in
            let progress = Progress(totalUnitCount: Int64(total))
            progress.completedUnitCount = Int64(completed)
            self.progressSender.send(progress)
        }

        log("Archive completed, registering artifact...")
        try backupManager.registerArtifact(session: self, atLocation: zipArchiveLocation)
        backupManager.clean(session: self)
    }
}

extension BackupSession {
    struct BackupLog: Identifiable, Equatable {
        var id: UUID = .init()
        let date = Date()
        let message: String
        enum Level: String, Codable {
            case log
            case percent
            case error
            case warning
        }

        let level: Level
        init(message: String, level: Level = .log) {
            self.message = message
            self.level = level
        }
    }

    func log(_ msg: String, level: BackupLog.Level = .log) {
        assert(!Thread.isMainThread)
        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            self.logs.append(.init(message: msg, level: level))
            self.progressText = msg
        })
    }
}

extension BackupSession: AppleMobileDeviceBackupDelegate {
    func isCancelled() -> Bool { cancelled }

    func backupRoot() -> URL { targetLocation }

    func manifestExtraInformation() -> AnyCodableDictionary? {
        [
            Constants.appName: AnyCodable([
                "Version": Constants.appVersion,
                "Build": Constants.appBuildVersion,
                "Project URL": Constants.projectUrl.absoluteString,
                "Copyright": Constants.copyrightNotice,
                "Signature": getSelfCodeSignature() ?? "Sign to Run Locally",
                "System": ProcessInfo.processInfo.operatingSystemVersionString,
                "System Identifier": getSystemUDID() ?? "00000000-0000-0000-0000-000000000000",
            ] as [String: String]),
        ]
    }

    func forceFullBackupMode() -> Bool { fullBackupMode }

    func arrival(checkpoint: AppleMobileDeviceBackup.Checkpoint) {
        if case let .deviceRequested(command) = checkpoint {
            _ = command // too much output
        } else {
            log("Checkpoint arrives at \(checkpoint)", level: .log)
        }
    }

    func failure(error: AppleMobileDeviceBackup.BackupError) {
        generalFailure(error: error)
    }

    func generalFailure(error: Error) {
        log("Received Failure! \(error): \(error.localizedDescription)", level: .error)

        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            let shouldInsert = !self.errors.contains {
                $0.localizedDescription == error.localizedDescription
            } // it will do the work
            if shouldInsert { self.errors.insert(error, at: 0) }
            self.cancelled = true
        })
    }

    func progressUpdate(_ progress: Double) {
        let p = Progress(totalUnitCount: 100)
        p.completedUnitCount = Int64(progress)
        let theProgress = Int(progress)
        if theProgress - lastProgressSent > 20, theProgress < 100 {
            lastProgressSent = theProgress
            log("Arriving \(theProgress)%", level: .percent)
            if device.config.notificationSendProgressPercent {
                var abc = [String](repeating: "░", count: 10)
                for i in 0 ..< abc.count where Double(i) / Double(abc.count) * 100 >= progress {
                    abc[i] = "█"
                }
                device.config.push(message: "\(abc.joined()) - \(theProgress)%")
            }
        }
        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            self.progress = p
        })
    }
}

extension AppleMobileDeviceManager.ConnectionMethod {
    var textDescription: String {
        switch self {
        case .usb: return "Wired Connection"
        case .net: return "Wireless Connection"
        case .usbPreferred: return "Any Connection, Wired Preferred"
        case .netPreferred: return "Any Connection, Wireless Preferred"
        case .any: return "Any Connection"
        }
    }
}

private extension BackupSession {
    func getSelfCodeSignature() -> String? {
        let defaultFlag = SecCSFlags(rawValue: 0)
        var code: SecCode?
        var staticCode: SecStaticCode?
        var resultCode = SecCodeCopySelf(defaultFlag, &code)
        guard resultCode == errSecSuccess, let secCode = code else { return nil }
        resultCode = SecCodeCopyStaticCode(secCode, defaultFlag, &staticCode)
        guard resultCode == errSecSuccess, let staticCode else { return nil }
        guard let certificates = getCertificates(code: staticCode)
        else { return nil }

        return String(describing: certificates)
    }

    private func getCertificates(code: SecStaticCode) -> [SecCertificate]? {
        var dict: CFDictionary?
        let code = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation), &dict
        )
        guard code == errSecSuccess, let info = dict as? [String: Any]
        else { return nil }
        guard let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate]
        else { return nil }
        return certs
    }

    func getSystemUDID() -> String? {
        let matchingDict = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict)
        defer { IOObjectRelease(platformExpert) }
        guard platformExpert != 0 else { return nil }
        return IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as? String
    }
}

extension AppleMobileDeviceBackup.DeviceCommand {
    var interfaceText: String {
        rawValue
    }
}

extension AppleMobileDeviceBackup.BackupError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation Cancelled"
        case .commandFailure:
            return "Failed to Execute Command"
        case .fileSystemFailure:
            return "File System Failure"
        case .unableToConnect:
            return "Unable to Connect"
        case .unableToHandshake:
            return "Unable to Perform Handshake"
        case .unableToStartService:
            return "Unable to Start Service"
        case .anotherBackupIsRunning:
            return "Another Backup is Running"
        case .unableToAcquireBackupPermission:
            return "Unable to Acquire Backup Permission"
        case .unableToBuildManifest:
            return "Unable to Build Manifest"
        case .unableToListAllApplications:
            return "Unable to List All Applications"
        case .unableToSendInitialCommand:
            return "Unable to Send Initial Command"
        case .unableToReciveCommandFromDevice:
            return "Unable to Receive Command From Device"
        case .receivedUnknownCommand:
            return "Received Unknown Command"
        case .unexpectedMessage:
            return "Unexpected Message Received"
        case .failedToCommunicateWithDevice:
            return "Failed to Communicate With Device"
        case let .receivedErrorFromDevice(code):
            return "Received Error From Device with Code: \(code)"
        case let .receivedErrorMessageFromDevice(description):
            return "Received Error Message From Device: \(description)"
        case let .other(error):
            return "Other Error: \(error)"
        default:
            return "Unknown Error Occurred"
        }
    }
}
