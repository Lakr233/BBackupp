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
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
        .commands { SidebarCommands() }
    }
}
