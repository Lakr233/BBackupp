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
        _ = appleDevice
        _ = deviceManager
        _ = backupManager

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Self.checkAllStorageLocation()
            deviceManager.startTimer()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
        .commands { SidebarCommands() }
    }

    static func checkAllStorageLocation() {
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

    static func requestPermission(atLocation: URL, error: Error?) {
        while true {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Please choose the storage directory in the next panel to grant us permission to store your backup."
            alert.informativeText = "Write error happens at \(atLocation.path): \(error?.localizedDescription ?? "unknown")"
            alert.addButton(withTitle: "Grant Permission")
            alert.addButton(withTitle: "Ignore Temporary")
            alert.addButton(withTitle: "Exit Application")
            let resp: NSApplication.ModalResponse
            if let window = NSApp.mainWindow {
                resp = alert.runSheetModal(for: window)
            } else {
                resp = alert.runModal()
            }
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
            savePanel.title = "Please select \(atLocation.path) and click Done"
            savePanel.prompt = "Grant Permission"

            if let window = NSApp.mainWindow {
                savePanel.runSheetModal(for: window)
            } else {
                savePanel.runModal()
            }
            if savePanel.url == atLocation { return }
        }
    }
}
