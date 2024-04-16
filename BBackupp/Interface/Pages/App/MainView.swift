//
//  MainView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import SwiftUI

private extension View {
    @ViewBuilder
    func limitMinSize() -> some View {
        frame(minWidth: 550, minHeight: 350)
    }
}

struct MainView: View {
    @AppStorage("AgreedToLicense") var agreedToLicense = false

    @StateObject var backupManager = bakManager

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 150, ideal: 150, max: 300)
        } detail: {
            WelcomeView().limitMinSize()
        }
        .navigationTitle(Constants.appName)
    }

    var sidebar: some View {
        List {
            Section("App") {
                NavigationLink {
                    WelcomeView().limitMinSize()
                } label: {
                    Label("Welcome", systemImage: "house")
                }
                NavigationLink {
                    TaskListView().limitMinSize()
                } label: {
                    Label("Tasks", systemImage: "paperplane")
                }
                .badge(backupManager.runningTaskCount)
                NavigationLink {
                    SettingsView().limitMinSize()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
            DeviceList()
            BackupPlanList()
        }
        .listStyle(.sidebar)
    }
}

private struct DeviceList: View {
    @StateObject var vm = devManager
    @State var openRegPanel = false

    var body: some View {
        Group {
            Section("Devices") {
                ForEach(vm.deviceList) { device in
                    NavigationLink {
                        DeviceView(udid: device.udid)
                            .limitMinSize()
                            .id(device.udid)
                    } label: {
                        Label(device.deviceName, systemImage: device.deviceSystemIcon)
                    }
                }
                Label("Add Device", systemImage: "apps.iphone.badge.plus")
                    .sheet(isPresented: $openRegPanel) {
                        RegisterSheetView()
                    }
                    .onTapGesture { openRegPanel = true }
            }
        }
    }
}

private struct BackupPlanList: View {
    @StateObject var vm = bakManager
    @State var openCreatePanel = false

    var body: some View {
        Group {
            Section("Backup Plan") {
                ForEach(vm.plans.keys.sorted(), id: \.self) { planID in
                    NavigationLink {
                        BackupPlanView(planID: planID)
                            .limitMinSize()
                            .id(planID)
                    } label: {
                        Label(vm.plans[planID]?.name ?? "", systemImage: "calendar")
                    }
                }
                Label("Create Plan", systemImage: "calendar.badge.plus")
                    .sheet(isPresented: $openCreatePanel) {
                        CreateBackupPlanPanelView()
                    }
                    .onTapGesture { openCreatePanel = true }
            }
        }
    }
}

extension UUID: Comparable {
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
