//
//  AppSetting.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import Foundation

let appSetting = AppSetting()

class AppSetting: ObservableObject {
    @PublishedStorage(key: "wiki.qaq.backup.temp.dir", defaultValue: documentDir.appendingPathComponent("Temp"))
    var tempBackupBase: URL

    @PublishedStorage(key: "wiki.qaq.backup.defaultMonitoringRangeFrom", defaultValue: 20 * 3600)
    var defaultMonitoringRangeFrom: Int // 20:00
    @PublishedStorage(key: "wiki.qaq.backup.defaultMonitoringRangeTo", defaultValue: 06 * 3600)
    var defaultMonitoringRangeTo: Int // 06:00

    @PublishedStorage(key: "wiki.qaq.app.heartbeat.address", defaultValue: "")
    var heartbeatAddress: String
    @PublishedStorage(key: "wiki.qaq.app.heartbeat.enabled", defaultValue: false)
    var heartbeatEnabled: Bool
    @Published var heartbeatLastSent: Date = .init(timeIntervalSince1970: 0)

    fileprivate init() {
        try? FileManager.default.createDirectory(at: tempBackupBase, withIntermediateDirectories: true)
    }

    func aliveCheckerHeartBeat() {
        guard heartbeatEnabled, !heartbeatAddress.isEmpty else { return }
        guard Date().timeIntervalSince(heartbeatLastSent) > 30 else { return }
        guard let url = URL(string: heartbeatAddress) else { return }
        heartbeatLastSent = Date()
        guard url.scheme?.lowercased().hasPrefix("http") ?? false else { return }
        let task = URLSession.shared.dataTask(with: url) { _, _, _ in }
        task.resume()
    }
}
