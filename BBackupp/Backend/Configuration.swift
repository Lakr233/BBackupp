//
//  Configuration.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import AppKit
import Combine

let documentDir = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent(Constants.appName)

class Configuration: NSObject, ObservableObject {
    static let shared = Configuration()
    var cancellable: Set<AnyCancellable> = .init()

    override private init() {
        super.init()
        try? FileManager.default.createDirectory(
            at: defaultBackupLocationUrl,
            withIntermediateDirectories: true
        )
        objectWillChange
            .sink { _ in
                self.save()
            }
            .store(in: &cancellable)
    }

    @PublishedStorage(key: "wiki.qaq.bbackupp.scanInterval", defaultValue: 3)
    var scanInterval: Int

    @PublishedStorage(key: "wiki.qaq.bbackupp.defaultBackupLocation", defaultValue: documentDir.path)
    var defaultBackupLocation: String

    var defaultBackupLocationUrl: URL {
        URL(fileURLWithPath: defaultBackupLocation)
    }

    @PublishedStorage(key: "wiki.qaq.bbackupp.defaultMonitoringRangeFrom", defaultValue: 20 * 3600)
    var defaultMonitoringRangeFrom: Int // 20:00
    @PublishedStorage(key: "wiki.qaq.bbackupp.defaultMonitoringRangeTo", defaultValue: 06 * 3600)
    var defaultMonitoringRangeTo: Int // 06:00

    var defaultMonitoringRangeDescrption: String {
        [
            String(defaultMonitoringRangeFrom / 3600).paddingInt(len: 2),
            ":",
            String((defaultMonitoringRangeFrom % 3600) / 60).paddingInt(len: 2),
            " -> ",
            String(defaultMonitoringRangeTo / 3600).paddingInt(len: 2),
            ":",
            String((defaultMonitoringRangeTo % 3600) / 60).paddingInt(len: 2),
            defaultMonitoringRangeTo < defaultMonitoringRangeFrom ? " (next day)" : "",
        ]
        .joined()
    }

    @PublishedStorage(key: "wiki.qaq.bbackupp.deviceConfiguration", defaultValue: [:])
    var deviceConfiguration: [Device.DevcieID: Device.Configuration]

    @PublishedStorage(key: "wiki.qaq.bbackupp.aliveCheckUrl", defaultValue: "")
    var aliveCheck: String

    public func switchDefaultBackupLocaiton(_ url: URL) {
        defaultBackupLocation = url.path
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for device in deviceManager.devices where device.config.backupLocation == nil {
            device.config.setupDir(atLocation: nil)
        }
        save()
    }

    public func save() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(saveNow), object: nil)
        perform(#selector(saveNow), with: nil, afterDelay: 1)
    }

    @objc func saveNow() {
        DispatchQueue.global().async {
            self._scanInterval.saveFromSubjectValueImmediately()
            self._defaultBackupLocation.saveFromSubjectValueImmediately()
            self._defaultMonitoringRangeFrom.saveFromSubjectValueImmediately()
            self._defaultMonitoringRangeTo.saveFromSubjectValueImmediately()
            self._deviceConfiguration.saveFromSubjectValueImmediately()
            self._aliveCheck.saveFromSubjectValueImmediately()
        }
    }
}
