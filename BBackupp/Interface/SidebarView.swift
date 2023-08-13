//
//  SidebarView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

struct SidebarView: View {
    @StateObject var deviceManager = DeviceManager.shared
    @StateObject var backupManager = BackupManager.shared

    @State var openDeviceInstruction: Bool = false

    var body: some View {
        Group {
            Section("App") {
                useNavigationLink {
                    WelcomeView()
                } label: {
                    Label("Automation", systemImage: "autostartstop")
                }
                useNavigationLink {
                    BackupProgressListView()
                } label: {
                    Label("Progress", systemImage: "checklist")
                }
                .badge(backupManager.runningBackups.count)
                useNavigationLink {
                    BackupListView()
                } label: {
                    Label("Backups", systemImage: "folder.badge.gearshape")
                }
                .badge(backupManager.totalBackups)
            }
            Section("Connected") {
                ForEach(deviceManager.pairedDevices) { device in
                    useNavigationLink {
                        DeviceConfigurationView(device: device)
                    } label: {
                        Label(device.deviceName, systemImage: device.deviceSystemIcon)
                    }
                }
                if deviceManager.pairedDevices.isEmpty {
                    Label("No Device", systemImage: "square.dashed")
                        .onTapGesture { openDeviceInstruction = true }
                }
            }
            Section("Untrusted") {
                ForEach(deviceManager.unpairedDevices) { device in
                    useNavigationLink {
                        UnpairedDeviceView(device: device)
                    } label: {
                        Label(device.deviceName, systemImage: "lock")
                    }
                }
                if deviceManager.unpairedDevices.isEmpty {
                    Label("No Device", systemImage: "square.dashed")
                        .onTapGesture { openDeviceInstruction = true }
                }
            }
            Section("Misc") {
                useNavigationLink {
                    SettingView()
                } label: {
                    Label("Setting", systemImage: "gear")
                }
            }
            Spacer()
                .sheet(isPresented: $openDeviceInstruction) {
                    PairInstructionView(openSheet: $openDeviceInstruction)
                }
        }
    }

    func useNavigationLink(destination: @escaping () -> some View, label: () -> some View) -> some View {
        NavigationLink {
            destination().frame(minWidth: 400, minHeight: 200)
        } label: {
            label()
        }
    }
}
