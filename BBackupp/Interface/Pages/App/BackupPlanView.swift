//
//  BackupPlanView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import SwiftUI

struct BackupPlanView: View {
    let planID: BackupPlan.ID
    @StateObject var backupManager = bakManager
    var plan: BackupPlan? { backupManager.plans[planID] }

    var body: some View {
        if let plan {
            BackupPlanEditorView(plan: plan)
        } else {
            Text("Backup Plan Removed")
                .bold()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BackupPlanEditorView: View {
    @StateObject var plan: BackupPlan
    var planID: BackupPlan.ID { plan.id }

    @StateObject var backupManager = bakManager
    @StateObject var deviceManager = devManager

    var device: Device? { deviceManager.devices[plan.deviceID] }

    @State var openDeleteAlert = false
    @State var openNotificationSetupPanel = false
    @State var openAccountManagerPanel = false
    @State var openBackupPlanPreview = false
    @State var openBackupPlanTask: BackupPlanTask? = nil

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                restic
                Divider()
                automation
                Divider()
                pluginNotification
                Divider()
                pluginApplicationDownloader
//                Divider()
//                pluginBinaryExecutor
                Divider()
                footer
            }
            .padding()
        }
        .navigationTitle("\(plan.name) - \(device?.deviceName ?? "???")")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {} label: {
                    Label("", systemImage: "calendar")
                }
            }

            ToolbarItem {
                Button { openDeleteAlert = true } label: {
                    Label("Delete Plan", systemImage: "trash")
                }
                .alert(isPresented: $openDeleteAlert) {
                    Alert(
                        title: Text("Are you sure you want to delete this plan? This will not delete your local storage. Remove it yourself."),
                        primaryButton: .destructive(Text("Delete")) {
                            backupManager.plans.removeValue(forKey: planID)
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            ToolbarItem {
                Button {} label: { Image(systemName: "circle.fill").opacity(0) }
                    .disabled(true)
            }

            ToolbarItem {
                Button {
                    let task = backupManager.planTasks
                        .filter(\.isRunning)
                        .filter { $0.context.device.udid == plan.deviceID }
                        .first
                    if let task {
                        openBackupPlanTask = task
                    } else {
                        openBackupPlanPreview = true
                    }
                } label: {
                    let task = backupManager.planTasks
                        .filter(\.isRunning)
                        .filter { $0.context.device.udid == plan.deviceID }
                        .first
                    return if task != nil {
                        Label("Watch Backup", systemImage: "figure.run")
                            .foregroundStyle(.green)
                    } else {
                        Label("Backup Now", systemImage: "paperplane")
                            .foregroundStyle(.accent)
                    }
                }
                .sheet(isPresented: $openBackupPlanPreview) {
                    BackupPlanTaskPreviewPanelView(plan: plan)
                }
                .sheet(item: $openBackupPlanTask) { task in
                    BackupPlanTaskView(task: task)
                }
            }
        }
    }

    // MARK: - Restic

    @ViewBuilder
    var restic: some View {
        SectionBuilder(title: "Restic") {
            Toggle(isOn: $plan.restic.enableChangeDetection) {
                Text("Enable Change Detection")
            }
            .disabled(true)
            Picker("Keep Backups", selection: $plan.automation.backupKeepOption) {
                ForEach(BackupPlan.Automation.BackupKeepOption.allCases) { value in
                    Text(value.interfaceText).tag(value)
                }
            }
        }
    }

    // MARK: - Automation

    @ViewBuilder
    var automation: some View {
        HStack(alignment: .top) {
            SectionBuilder(title: "Automation") {
                VStack(alignment: .leading) {
                    Toggle(isOn: $plan.automation.enabled) {
                        Text("Enable Automation")
                    }
                    Toggle(isOn: $plan.automation.deviceWirelessConnectionEnabled) {
                        Text("Allow Wireless Connection")
                    }
                    Toggle(isOn: $plan.automation.deviceRequiresCharging) {
                        Text("Requires Charging")
                    }
                    Toggle(isOn: $plan.automation.customizedBackupTimeRangeEnabled) {
                        Text("Customize Monitor Schedule")
                    }
                    HStack {
                        DatePicker("From", selection: .init(get: {
                            Calendar.current.startOfDay(for: Date())
                                .addingTimeInterval(TimeInterval(plan.automation.customizedBackupFrom))
                        }, set: { date in
                            plan.automation.customizedBackupFrom = Int(date.timeIntervalSince1970
                                - Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
                        }), displayedComponents: .hourAndMinute)
                        DatePicker("To", selection: .init(get: {
                            Calendar.current.startOfDay(for: Date())
                                .addingTimeInterval(TimeInterval(plan.automation.customizedBackupTo))
                        }, set: { date in
                            plan.automation.customizedBackupTo = Int(date.timeIntervalSince1970
                                - Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
                        }), displayedComponents: .hourAndMinute)
                    }
                    .disabled(!plan.automation.customizedBackupTimeRangeEnabled)
                    Text(plan.automation.backupMonitorDescription)
                        .font(.footnote)
                        .padding(.top, 1)
                        .opacity(0.5)
                }
            }
            Spacer()
            SectionBuilder(title: "Weekday Scheduler") {
                HStack(alignment: .top, spacing: 32) {
                    VStack(alignment: .leading) {
                        Toggle(isOn: $plan.automation.automaticBackupOnMonday) { Text("Monday") }
                        Toggle(isOn: $plan.automation.automaticBackupOnTuesday) { Text("Tuesday") }
                        Toggle(isOn: $plan.automation.automaticBackupOnWednesday) { Text("Wednesday") }
                        Toggle(isOn: $plan.automation.automaticBackupOnThursday) { Text("Thursday") }
                        Toggle(isOn: $plan.automation.automaticBackupOnFriday) { Text("Friday") }
                    }
                    VStack(alignment: .leading) {
                        Toggle(isOn: $plan.automation.automaticBackupOnSaturday) { Text("Saturday") }
                        Toggle(isOn: $plan.automation.automaticBackupOnSunday) { Text("Sunday") }
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Plugin - Notification

    @ViewBuilder
    var pluginNotification: some View {
        SectionBuilder(title: "Plugin - Notification") {
            Text("Notification plugin supports multiple way to notify backup progress and result to devices.")
            HStack {
                Picker("Notification Provider", selection: $plan.notification.provider) {
                    ForEach(BackupPlan.Notification.Provider.allCases, id: \.self) { input in
                        Text(input.interfaceText).tag(input)
                    }
                }
                Button("Setup") { openNotificationSetupPanel = true }
                    .disabled(plan.notification.provider == .none)
                    .sheet(isPresented: $openNotificationSetupPanel) {
                        switch plan.notification.provider {
                        case .bark: BarkNotificationSetupPanelView(plan: plan)
                        case .telegram: TelegramNotificationSetupPanelView(plan: plan)
                        default: Text("Not Available").onAppear { openNotificationSetupPanel = false }
                        }
                    }
            }
            HStack {
                Toggle("Enabled", isOn: $plan.notification.enabled)
                Toggle("Backup Progress (Percent)", isOn: $plan.notification.sendProgressPercent)
            }
        }
    }

    // MARK: - Plugin - App Store Connect

    @ViewBuilder
    var pluginApplicationDownloader: some View {
        SectionBuilder(title: "Plugin - App Store Connect") {
            Text("Backup ipa from App Store after backup completed. Accounts are shared across all backup plans.")
            Button("Manage Accounts") { openAccountManagerPanel = true }
                .sheet(isPresented: $openAccountManagerPanel) {
                    AppStoreAccountView()
                }
            HStack {
                Toggle("Enabled", isOn: $plan.appStoreConnect.enabled)
                Toggle("Ignore Failure", isOn: $plan.appStoreConnect.ignoreFailure)
            }
        }
    }

    // MARK: - Plugin - Analyzer

    // TODO: IMPL

    @ViewBuilder
    var pluginBinaryExecutor: some View {
        SectionBuilder(title: "Plugin - Analyzer") {
            Text("Execute binary command after backup completed. [See documents](https://).")
            Toggle("Enabled", isOn: $plan.analyzer.enabled)
            HStack {
                Text("Backup Password")
                SecureField("", text: $plan.analyzer.backupPassword)
            }
            ForEach(0 ..< plan.analyzer.binaryExecutors.count, id: \.self) { idx in
                HStack {
                    Toggle(plan.analyzer.binaryExecutors[idx].name, isOn: .init(
                        get: { plan.analyzer.binaryExecutors[idx].enabled },
                        set: { plan.analyzer.binaryExecutors[idx].enabled = $0 }
                    ))
                    Spacer()
                    Button("Remove") {}
                }
            }
            Button("Add Analyzer") {}
        }
    }

    @ViewBuilder
    var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Repository: \(plan.resticRepo.location)")
            Text("Associated Device ID: \(device?.udid ?? "")")
            Text("Backup Plan ID: \(plan.id)")
            Text("Restic Repo ID: \(plan.resticRepo.id)")
        }
        .textSelection(.enabled)
        .font(.footnote)
        .opacity(0.5)
    }
}

#Preview {
    BackupPlanView(planID: bakManager.plans.first!.value.id)
        .frame(width: 500, height: 500, alignment: .center)
}
