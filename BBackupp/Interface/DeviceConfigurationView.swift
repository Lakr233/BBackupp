//
//  DeviceConfigurationView.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/11.
//

import SwiftUI

struct DeviceConfigurationView: View {
    @StateObject var device: Device
    @StateObject var config: Configuration = .shared
    @StateObject var backupManager: BackupManager = .shared

    @State var openProgressReason: String = ""
    @State var openProgress: Bool = false {
        didSet { if !openProgress { openProgressReason = "" } }
    }

    @State var openDeviceInfo: Bool = false
    @State var openDeviceBackups: Bool = false
    @State var openNotificationProviderSetup: Bool = false

    @State var backupSession: BackupSession?

    init(device: Device) {
        _device = .init(wrappedValue: device)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading) {
                information
                Divider()
                Group {
                    storage
                    Divider()
                    automation
                    Divider()
                    notification
                    Divider()
                    miscellaneous
                }
                Divider()
                HStack(alignment: .center) {
                    Image(systemName: "text.append")
                    Text("End of File")
                }
                .font(.footnote)
            }
            .padding()
        }
        .toolbar { toolbarItems }
        .sheet(isPresented: $openProgress) {
            UITemplate.makeProgress(text: $openProgressReason)
        }
        .sheet(isPresented: $openDeviceBackups) {
            UITemplate.makeSheet(title: "Backups", rightButton: "Done") {
                AnyView(BackupListView(device: device.universalDeviceIdentifier, allowToolbar: false))
            } complete: { _ in
                openDeviceBackups = false
            }
            .frame(minWidth: 600)
        }
        .sheet(isPresented: $openNotificationProviderSetup) {
            UITemplate.makeSheet(
                title: "Setup Push Notification",
                leftButton: "Test",
                rightButton: "Done"
            ) {
                AnyView(NotificationSetupView(
                    provider: $device.config.notificationProvider,
                    config: $device.config.notificationProviderConfig
                ))
            } complete: { isRightButtonReturn in
                if isRightButtonReturn {
                    openNotificationProviderSetup = false
                } else {
                    openProgressReason = "Sending Notification"
                    openProgress = true
                    deviceManager.send(
                        message: "Congratulations! 🎉 Your notification provider is now working!",
                        toDeviceWithIdentifier: device.universalDeviceIdentifier
                    ) { result in
                        DispatchQueue.main.async {
                            if case let .failure(error) = result {
                                UITemplate.makeErrorAlert(with: error) {
                                    openProgress = false
                                }
                            } else {
                                openProgress = false
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $backupSession) { session in
            BackupSessionDetailSheet(session: session) {
                backupSession = nil
            }
        }
        .navigationTitle("\(device.deviceName) - Backup Configuration")
    }

    var information: some View {
        UITemplate.buildSection("") {
            HStack {
                Image(systemName: device.deviceSystemIcon)
                    .font(.system(size: 32, weight: .regular, design: .rounded))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(device.deviceName) - \(device.deviceRecord?.productType ?? "???")")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("\(device.deviceRecord?.productVersion ?? "???") \(device.universalDeviceIdentifier)")
                        .font(.system(.footnote))
                }
                Spacer()
                Button("Manage Backups") {
                    openDeviceBackups = true
                }
                Button(
                    backupManager.isRunningForDevice(withIdentifier: device.universalDeviceIdentifier)
                        ? "View Progress"
                        : "Backup"
                ) {
                    if let runningSession = backupManager.runningSessionForDevice(withIdentifier: device.udid) {
                        backupSession = runningSession
                    } else {
                        UITemplate.makeConfirmation(
                            message: "Do you wish to start a full backup?",
                            firstButtonText: "Incremental",
                            secondButtonText: "Full Backup"
                        ) { isFirstButtonReturn in
                            backupSession = backupManager.startBackupSession(
                                forDevice: device,
                                fullBackupMode: !isFirstButtonReturn
                            )
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .textSelection(.enabled)
        }
    }

    var storage: some View {
        UITemplate.buildSection("Storage") {
            Group {
                HStack {
                    TextField(
                        "Storage Location",
                        text: device.config.backupLocation == nil
                            ? .constant("\(device.config.storeLocationURL.path) (default)")
                            : .constant(device.config.storeLocationURL.path)
                    )
                    .disabled(true)
                    Button(device.config.backupLocation == nil ? "Select" : "Reset") {
                        if device.config.backupLocation == nil {
                            UITemplate.requestToSave(
                                filename: device.config.defaultBackupDirName,
                                startDir: documentDir.path
                            ) { url in
                                guard let url else { return }
                                device.config.backupLocation = url.path
                                device.config.setupDir(atLocation: url)
                            }
                        } else {
                            device.config.backupLocation = nil
                            device.config.setupDir(atLocation: nil)
                        }
                    }
                }
                HStack {
                    Text("Mount: \(device.config.storeLocationURL.mountPoint.path)")
                        .textSelection(.enabled)
                    Text("\(device.config.storeLocationURL.getFreeSpaceSize())/\(device.config.storeLocationURL.getTotalSpaceSize())")
                        .textSelection(.enabled)
                    Spacer()
                    Text("Reveal in Finder")
                        .underline()
                        .foregroundColor(.accentColor)
                        .onTapGesture {
                            NSWorkspace.shared.open(device.config.storeLocationURL)
                        }
                }
                .font(.system(.footnote))
            }
        }
    }

    var automation: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                UITemplate.buildSection("Automation") {
                    Group {
                        Toggle(isOn: $device.config.automaticBackupEnabled) {
                            Text("Enable Automation")
                        }
                        Toggle(isOn: $device.config.wirelessBackupEnabled) {
                            Text("Wireless Backup")
                        }
                        .onChange(of: device.config.wirelessBackupEnabled) { newValue in
                            if newValue, !device.extra.isWirelessConnectionEnabled {
                                switchWirelessFeature()
                            }
                        }
                        Group {
                            Toggle(isOn: $device.config.requiresCharging) {
                                Text("Requires Charging")
                            }
                            Toggle(isOn: $device.config.customizedBackupTimeRangeEnabled) {
                                Text("Customize Monitor Schedule")
                            }
                            if device.config.customizedBackupTimeRangeEnabled {
                                HStack {
                                    DatePicker("From", selection: .init(get: {
                                        Calendar.current.startOfDay(for: Date())
                                            .addingTimeInterval(TimeInterval(device.config.customizedBackupFrom))
                                    }, set: { date in
                                        device.config.customizedBackupFrom = Int(date.timeIntervalSince1970
                                            - Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
                                    }), displayedComponents: .hourAndMinute)
                                    DatePicker("To", selection: .init(get: {
                                        Calendar.current.startOfDay(for: Date())
                                            .addingTimeInterval(TimeInterval(device.config.customizedBackupTo))
                                    }, set: { date in
                                        device.config.customizedBackupTo = Int(date.timeIntervalSince1970
                                            - Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
                                    }), displayedComponents: .hourAndMinute)
                                }
                            }
                            Text("Backup during \(device.config.backupMonitorDescription) \(device.config.customizedBackupTimeRangeEnabled ? "" : "default")")
                                .font(.system(.footnote))
                            Picker(selection: $device.config.backupKeepOption) {
                                ForEach(Device.Configuration.BackupKeepOption.allCases) { each in
                                    Text(each.interfaceText).tag(each)
                                }
                            } label: {
                                Group {}
                            }
                        }
                        .disabled(!device.config.automaticBackupEnabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 20, height: 0)
            VStack(alignment: .leading) {
                UITemplate.buildSection("Backup Schedule") {
                    HStack(alignment: .top, spacing: 32) {
                        VStack(alignment: .leading) {
                            Toggle(isOn: $device.config.automaticBackupOnMonday) { Text("Monday") }
                            Toggle(isOn: $device.config.automaticBackupOnTuesday) { Text("Tuesday") }
                            Toggle(isOn: $device.config.automaticBackupOnWednesday) { Text("Wednesday") }
                            Toggle(isOn: $device.config.automaticBackupOnThursday) { Text("Thursday") }
                            Toggle(isOn: $device.config.automaticBackupOnFriday) { Text("Friday") }
                        }
                        VStack(alignment: .leading) {
                            Toggle(isOn: $device.config.automaticBackupOnSaturday) { Text("Saturday") }
                            Toggle(isOn: $device.config.automaticBackupOnSunday) { Text("Sunday") }
                        }
                    }
                }
            }
            .disabled(!device.config.automaticBackupEnabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var notification: some View {
        UITemplate.buildSection("Notification") {
            VStack(alignment: .leading) {
                HStack {
                    Picker("Service Provider", selection: $device.config.notificationProvider) {
                        ForEach(Device.Configuration.NotificationProvider.allCases) { provider in
                            Text(provider.interfaceText).tag(provider)
                        }
                    }
                    Button("Setup") {
                        openNotificationProviderSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(device.config.notificationProvider == .none)
                }
                Text(device.config.notificationProvider.descriptionText)
                    .font(.footnote)
                    .textSelection(.enabled)
                HStack {
                    Toggle(isOn: $device.config.notificationEnabled) {
                        Text("Notification Enabled")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle(isOn: $device.config.notificationSendProgressPercent) {
                        Text("Send Percentage Progress")
                    }
                    .disabled(!device.config.notificationEnabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    var miscellaneous: some View {
        UITemplate.buildSection("Miscellaneous") {
            HStack {
                WiredToggleView(isOn: $device.extra.isWirelessConnectionEnabled) {
                    AnyView(Text("Wireless Connection"))
                } tapped: {
                    switchWirelessFeature()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                WiredToggleView(isOn: $device.extra.isBackupEncryptionEnabled) {
                    AnyView(Text("Encrypt Backup"))
                } tapped: {
                    if device.extra.isBackupEncryptionEnabled {
                        UITemplate.askForInputText(
                            title: "Backup Password Required",
                            message: "Are you sure you want to disable backup encryption? Some of your sensitive data is only available with encrypted backup mode.",
                            confirmButton: "Disable Encryption",
                            cancelButton: "Cancel",
                            placeholder: "",
                            isPassword: true
                        ) { pass in
                            guard let pass else { return }
                            appleDevice.disableBackupPassword(udid: device.universalDeviceIdentifier, currentPassword: pass)
                            UITemplate.makeAlert(withMessage: "Please continue on device", delay: 0.5) {
                                DispatchQueue.global().async {
                                    deviceManager.scanDeviceStatus()
                                }
                            }
                        }
                    } else {
                        UITemplate.askForInputText(
                            title: "Backup Password Required",
                            message: "Please set a password for your backup.",
                            confirmButton: "Enable Encryption",
                            cancelButton: "Cancel",
                            placeholder: "",
                            isPassword: true
                        ) { inputA in
                            guard let inputA else { return }
                            UITemplate.askForInputText(
                                title: "Backup Password Required",
                                message: "Please confirm your password.",
                                confirmButton: "Enable Encryption",
                                cancelButton: "Cancel",
                                placeholder: "",
                                isPassword: true
                            ) { inputB in
                                guard let inputB else { return }
                                guard inputA == inputB else {
                                    UITemplate.makeErrorAlert(with: "Password Mismatch")
                                    return
                                }
                                appleDevice.enableBackupPassword(udid: device.universalDeviceIdentifier, password: inputA)
                                UITemplate.makeAlert(withMessage: "Please continue on device", delay: 0.5) {
                                    DispatchQueue.global().async {
                                        deviceManager.scanDeviceStatus()
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem {
                Button {
                    UITemplate.makeConfirmation(
                        message: "Unpairing is irreversible.",
                        firstButtonText: "Continue",
                        secondButtonText: "Cancel"
                    ) { confirmed in
                        guard confirmed else { return }
                        appleDevice.unpaireDevice(udid: device.universalDeviceIdentifier)
                        UITemplate.makeAlert(withMessage: "Please disconnect the device to complete the process.") {
                            DispatchQueue.global().async {
                                deviceManager.scanDeviceIfNeeded()
                            }
                        }
                    }
                } label: {
                    Label("Unpair", systemImage: "trash")
                }
            }
            ToolbarItem {
                Button {
                    UITemplate.makeConfirmation(
                        message: "This operation is irreversible",
                        firstButtonText: "Reset Configuration to Defaut"
                    ) { confirmed in
                        guard confirmed else { return }
                        device.config = .init(universalDeviceIdentifier: device.universalDeviceIdentifier)
                    }
                } label: {
                    Label("Reset to Default", systemImage: "arrow.uturn.backward.circle.badge.ellipsis")
                }
            }
            ToolbarItem {
                Button {
                    takeScreenshot()
                } label: {
                    Label("Take Screenshot", systemImage: "camera")
                }
            }
            ToolbarItem {
                Button {
                    openDeviceInfo = true
                } label: {
                    Label("Device Info", systemImage: device.deviceSystemIcon)
                }
                .sheet(isPresented: $openDeviceInfo) {
                    DeviceInfoSheet(device: device, openSheet: $openDeviceInfo)
                }
            }
        }
    }

    func takeScreenshot() {
        openProgressReason = "Receiving Image Data"
        openProgress = true
        DispatchQueue.global().async {
            guard let data = appleDevice
                .obtainDeviceScreenshot(udid: device.universalDeviceIdentifier),
                let image = NSImage(data: data)
            else {
                UITemplate.makeErrorAlert(with: "Unable to receive screenshot, make sure developer mode is enabled on your device with Developer Image mounted") {
                    DispatchQueue.main.async {
                        openProgress = false
                    }
                }
                return
            }
            let filenameDate = Date()
                .formatted(date: .numeric, time: .standard)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ",", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "--", with: "-")
            UITemplate.requestToSave(
                filename: "Screenshot-\(device.deviceName)-\(filenameDate).png"
            ) { url in
                guard let url else {
                    openProgress = false
                    return
                }
                do {
                    try image.png?.write(to: url, options: .atomic)
                    openProgress = false
                } catch {
                    UITemplate.makeErrorAlert(with: error) {
                        openProgress = false
                    }
                }
            }
        }
    }

    func switchWirelessFeature(confirm: Bool = false) {
        let newValue = !device.extra.isWirelessConnectionEnabled
        if !newValue, !confirm {
            UITemplate.makeConfirmation(
                message: "You will need to reconnect with a cable to enable this feature",
                firstButtonText: "Disable Wireless Connection",
                secondButtonText: "Cancel"
            ) { confirmed in
                if confirmed {
                    switchWirelessFeature(confirm: true)
                }
            }
        } else {
            openProgressReason = "Configuring Device"
            openProgress = true
            DispatchQueue.global().async {
                appleDevice.setDeviceWirelessConnectionEnabled(
                    udid: device.universalDeviceIdentifier,
                    enabled: newValue
                )
                sleep(3)
                device.populateDeviceInfo()
                DispatchQueue.main.async {
                    openProgress = false
                }
            }
        }
    }
}
