//
//  DeviceManager.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import AppleMobileDevice
import Combine
import Foundation
import libAppleMobileDevice

class DeviceManager: NSObject, ObservableObject {
    static let shared = DeviceManager()

    @Published var isScaning = false

    private var devicesStore: [Device] = []

    var devices: [Device] {
        Array(devicesStore).sorted { $0.udid < $1.udid }
    }

    var pairedDevices: [Device] {
        devices.filter(\.extra.isPaired)
    }

    var unpairedDevices: [Device] {
        devices.filter { !$0.extra.isPaired }
    }

    var automaticBackupEnabledDevices: [Device] {
        devices.filter(\.config.automaticBackupEnabled).sorted {
            $0.udid < $1.udid
        }
    }

    override private init() {
        super.init()
    }

    func startTimer() {
        let timer = Timer(
            timeInterval: 1,
            target: self,
            selector: #selector(scanDeviceIfNeeded),
            userInfo: nil,
            repeats: true
        )
        Thread {
            self.scanDeviceStatus()
            RunLoop.current.add(timer, forMode: .common)
            RunLoop.current.run()
        }.start()
    }

    private var scanDeviceIntervalCounter = 0
    @objc func scanDeviceIfNeeded() {
        scanDeviceIntervalCounter += 1
        if scanDeviceIntervalCounter > appConfiguration.scanInterval {
            scanDeviceIntervalCounter = 0
            scanDeviceStatus()
            backupManager.backupRobotHeartBeat()
        }
    }

    public func scanDeviceStatus() {
        defer {
            DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
                self.isScaning = false
            })
        }

        assert(!Thread.isMainThread)
        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            self.isScaning = true
        })

        let identifiers = appleDevice.listDeviceIdentifiers()
        var buildDevices = [Device]()
        for udid in identifiers {
            var device: Device? = devicesStore
                .first { $0.universalDeviceIdentifier == udid }
            if device == nil {
                let build = Device(udid: udid)
                device = build
                DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
                    self.devicesStore.append(build)
                })
            }
            if let device { buildDevices.append(device) }
        }

        let removed = devicesStore
            .map(\.universalDeviceIdentifier)
            .filter { !identifiers.contains($0) }
        if !removed.isEmpty {
            DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
                self.devicesStore = self.devicesStore
                    .filter { !removed.contains($0.universalDeviceIdentifier) }
            })
        }

        if devices.count != Set(devices.map(\.udid)).count {
            DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
                print("[?] fixing up duplicated devices") // just lazy, this wont happen again
                self.devicesStore = []
            })
        }

        let group = DispatchGroup()
        let sem = DispatchSemaphore(value: 8)
        for device in buildDevices {
            group.enter()
            sem.wait()
            DispatchQueue.global().async {
                defer {
                    group.leave()
                    sem.signal()
                }
                device.populateDeviceInfo()
            }
        }
        group.wait()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

extension Device {
    func populateDeviceInfo() {
        assert(!Thread.isMainThread)

        let deviceRecord = appleDevice.obtainDeviceInfo(udid: udid)
        let pairRecord = appleDevice.obtainPairRecord(udid: udid)
        let isPaired = appleDevice.isDevicePaired(udid: udid) ?? false
        let isWirelessConnectionEnabled = appleDevice.isDeviceWirelessConnectionEnabled(udid: udid) ?? false
        let isBackupEncryptionEnabled = appleDevice.isBackupEncryptionEnabled(udid: udid) ?? false

        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            self.deviceRecord = deviceRecord
            self.pairRecord = pairRecord
            self.extra.isPaired = isPaired
            self.extra.isWirelessConnectionEnabled = isWirelessConnectionEnabled
            self.extra.isBackupEncryptionEnabled = isBackupEncryptionEnabled
        })
    }
}

extension DeviceManager {
    enum PushNotificationError: Error {
        case deviceConfigNotFound
        case deviceNotConfiguredForPushNotification
        case unknown
    }

    public func send(message: String, toDeviceWithIdentifier udid: Device.DevcieID, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let deviceConfig = appConfiguration.deviceConfiguration[udid] else {
            completion?(.failure(PushNotificationError.deviceConfigNotFound))
            return
        }
        let serviceProvider = deviceConfig.notificationProvider
        guard serviceProvider != .none else {
            completion?(.failure(PushNotificationError.deviceNotConfiguredForPushNotification))
            return
        }
        deviceConfig.push(message: message) { result in
            completion?(result)
        }
    }
}
