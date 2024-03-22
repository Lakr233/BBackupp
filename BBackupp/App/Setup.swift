//
//  Setup.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/5.
//

import AppKit
import Foundation

func setupApplication() {
    do {
        try setupApplicationEx()
    } catch {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }
}

extension MuxProxy {
    fileprivate(set) static var shared: MuxProxy!
}

private func setupApplicationEx() throws {
    if !FileManager.default.fileExists(atPath: documentDir.path) {
        try FileManager.default.createDirectory(
            at: documentDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    if !FileManager.default.fileExists(atPath: tempDir.path) {
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    _ = appSetting
    _ = amdManager
    _ = devManager
    _ = bakManager

    _ = AppStoreBackend.shared

    for plan in bakManager.plans.values {
        plan.resticRepo.unlock()
    }

    MuxProxy.shared = try MuxProxy()

    try? FileManager.default.createDirectory(
        at: BackupTask.defaultBase,
        withIntermediateDirectories: true
    )

    let queue = DispatchQueue(label: "wiki.qaq.timer", attributes: .concurrent)
    let timer = Timer(timeInterval: 5, repeats: true) { _ in
        queue.async { bakManager.backupRobotHeartBeat() }
        queue.async { appSetting.aliveCheckerHeartBeat() }
    }
    RunLoop.current.add(timer, forMode: .common)
}
