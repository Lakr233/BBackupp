//
//  BBackuppApp.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/10.
//

import AppleMobileDevice
import SwiftUI

let deviceManager = DeviceManager.shared
let backupManager = BackupManager.shared
let appleDevice = AppleMobileDeviceManager.shared
let appConfiguration = Configuration.shared

@main
struct BBackuppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = appConfiguration
        checkAllStorageLocation()

        _ = appleDevice
        _ = deviceManager
        _ = backupManager
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
        .commands { SidebarCommands() }
    }

    func checkAllStorageLocation() {
        appConfiguration.deviceConfiguration.values.forEach { config in
            let dir = config.storeLocationURL
            let signalFile = dir.appendingPathComponent(".PermissionCheck")
            try? FileManager.default.removeItem(at: signalFile)
            do {
                try String("Hello World").write(to: signalFile, atomically: true, encoding: .utf8)
            } catch {
                requestPermission(atLocation: dir, error: error)
            }
        }
    }

    func requestPermission(atLocation: URL, error: Error?) {
        while true {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "We are unable to write to storage location for your backup, please select storage directory in the up coming panel to grant us the permission."
            alert.informativeText = error?.localizedDescription ?? atLocation.path
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Ignore")
            alert.addButton(withTitle: "Exit")
            let resp = alert.runModal()
            switch resp {
            case .alertFirstButtonReturn: break
            case .alertSecondButtonReturn: return
            case .alertThirdButtonReturn: exit(0)
            default:
                assertionFailure()
                return
            }
            let savePanel = NSSavePanel()
            savePanel.directoryURL = atLocation.deletingLastPathComponent()
            savePanel.nameFieldStringValue = atLocation.lastPathComponent
            savePanel.runModal()
            if savePanel.url == atLocation { return }
        }
    }
}
