//
//  BackupManager.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import Combine
import Foundation

class BackupManager: NSObject, ObservableObject {
    static let shared = BackupManager()
    var cancellable: Set<AnyCancellable> = .init()

    override private init() {
        super.init()
        let timer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(backupRobotHeartBeat),
            userInfo: nil,
            repeats: true
        )
        Thread {
            RunLoop.current.add(timer, forMode: .common)
            RunLoop.current.run()
        }.start()
    }

    @Published var backupSession: [BackupSession] = []
    var runningBackups: [BackupSession] {
        backupSession.filter(\.isRunning)
    }

    @PublishedStorage(key: "wiki.qaq.bbackupp.backupList", defaultValue: [:])
    var backupList: [Device.DevcieID: [Backup]]
    var totalBackups: Int {
        backupList.values.map(\.count).reduce(0, +)
    }

    @PublishedStorage(key: "wiki.qaq.bbackupp.lastBackupAttempt", defaultValue: [:])
    var lastBackupAttempt: [Device.DevcieID: Date]

    func isRunningForDevice(withIdentifier udid: Device.DevcieID) -> Bool {
        runningSessionForDevice(withIdentifier: udid) != nil
    }

    func runningSessionForDevice(withIdentifier udid: Device.DevcieID) -> BackupSession? {
        runningBackups.first { $0.device.universalDeviceIdentifier == udid }
    }

    @discardableResult
    func startBackupSession(forDevice device: Device, fullBackupMode: Bool) -> BackupSession {
        assert(Thread.isMainThread)
        if let session = runningSessionForDevice(withIdentifier: device.universalDeviceIdentifier) {
            return session
        }
        let session = BackupSession(device: device, fullBackupMode: fullBackupMode)
        let listener = session.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in
                self.objectWillChange.send()
            }
        listener.store(in: &cancellable)
        backupSession.insert(session, at: 0)
        session.startBackupRoutine()
        lastBackupAttempt[device.universalDeviceIdentifier] = Date()
        return session
    }

    func registerArtifact(session: BackupSession, atLocation: URL) throws {
        let transferLocation = session.device.config
            .storeLocationURL
            .appendingPathComponent(atLocation.lastPathComponent)
        try FileManager.default.moveItem(at: atLocation, to: transferLocation)
        let backup = Backup(session: session, zipLocation: transferLocation)
        var build = backupList[session.device.universalDeviceIdentifier, default: []]
        build.append(backup)
        DispatchQueue.main.async {
            self.backupList[session.device.universalDeviceIdentifier] = build
        }
    }

    func clean(session: BackupSession) {
        // since it is only called after registerArtifact so should be good to remove it
        assert(session.targetLocation.path.contains("InProgress"))
        let currentBackupCache = session.targetLocation
            .appendingPathComponent(session.device.universalDeviceIdentifier)
        // valid backup, create for incremental backup
        if FileManager.default.fileExists(atPath: currentBackupCache.path), session.errors.isEmpty {
            let incrementalCacheUrl = session.device.config.incrementalCacheUrl
            try? FileManager.default.removeItem(at: incrementalCacheUrl)
            try? FileManager.default.moveItem(at: currentBackupCache, to: incrementalCacheUrl)
        }
        // now remove all
        try? FileManager.default.removeItem(at: session.targetLocation)
        try? FileManager.default.removeItem(at: session.device.config.inProgressUrl)
    }

    func cleanCompleted() {
        backupSession = runningBackups
    }

    func backup(withDeviceID udid: String?) -> [Backup] {
        if let udid {
            return backupList[udid, default: []]
        }
        return backupList.values.reduce([], +)
    }

    func backup(withBackID: Backup.ID) -> Backup? {
        backupList.values.reduce([], +).first { $0.id == withBackID }
    }

    func delete(backups deleteList: [Backup.ID]) {
        guard !deleteList.isEmpty else { return }
        var rebuild = [Device.ID: [Backup]]()
        var destroyList = [Backup]()
        for device in backupList.keys {
            let deviceBackups = backupList[device, default: []]
                .compactMap { backup -> Backup? in
                    if deleteList.contains(backup.id) {
                        destroyList.append(backup)
                        return nil
                    } else {
                        return backup
                    }
                }
            if deviceBackups.isEmpty { continue }
            rebuild[device] = deviceBackups
        }
        DispatchQueue.main.async {
            self.backupList = rebuild
            self.objectWillChange.send()
        }

        // just delay destory after triggers save
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            destroyList.forEach { Backup.destroy(backup: $0) }
        }
    }

    public func save() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(saveNow), object: nil)
        perform(#selector(saveNow), with: nil, afterDelay: 1)
    }

    @objc func saveNow() {
        DispatchQueue.global().async {
            self._backupList.saveFromSubjectValueImmediately()
        }
    }

    private var deviceStatusRecorder: [Device.DevcieID: DeviceStatus] = [:]
    private struct DeviceStatus {}

    @objc func backupRobotHeartBeat() {
        // the automatic backup happens here!
        deviceManager.devices.forEach {
            let noLongerNeeded = $0.config.walkthroughAndReturnBackupThatIsNoLongerNeeded(
                backups: backupList[$0.universalDeviceIdentifier, default: []]
            )
            DispatchQueue.main.asyncAndWait {
                self.delete(backups: noLongerNeeded)
            }
        }
        for device in deviceManager.devices where device.config.automaticBackupEnabled {
            guard device.config.needsBackup(udid: device.universalDeviceIdentifier)
            else { continue }
            // now the config tells us it is ok to backup
            // but we need to check if there is already an attempt in a somehow short-term
            // for now let's just say whith in 18 hours
            // TODO: A Better Algorithem

            let lastAttempt = lastBackupAttempt[
                device.universalDeviceIdentifier,
                default: Date(timeIntervalSince1970: 0)
            ]
            guard Date().timeIntervalSince(lastAttempt) > 18 * 3600 else { return }
            DispatchQueue.main.async {
                self.startBackupSession(forDevice: device, fullBackupMode: false)
            }
        }
    }
}
