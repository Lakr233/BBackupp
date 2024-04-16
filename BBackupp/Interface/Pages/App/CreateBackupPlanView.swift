//
//  CreateBackupPlanView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import SwiftUI

struct CreateBackupPlanPanelView: View {
    let spacing: CGFloat = 16
    @Environment(\.dismiss) var dismiss

    @State var name: String = "Plan \(Int.random(in: 10000 ... 99999))"
    @State var repo: ResticRepo = .init(location: "")
    @State var udid: Device.ID = ""
    @State var openEnvironmentSetupPanel = false
    @State var openProgress = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Create Backup Plan").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(spacing)
            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    setup()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(spacing)
        }
        .sheet(isPresented: $openProgress) {
            ProgressPanelView()
        }
        .frame(width: 550)
    }

    @ViewBuilder
    var content: some View {
        nameSetup
        resticSetup
        deviceSetup
        Text("Once the backup plan is created, you can not change these settings.")
            .font(.footnote)
            .underline()
            .foregroundStyle(.red)
    }

    @ViewBuilder
    var nameSetup: some View {
        Text("Plan Name")
            .bold()
        TextField("Storage Repository Location", text: $name)
    }

    @ViewBuilder
    var resticSetup: some View {
        Text("Restic Storage")
            .bold()
        TextField("", text: $repo.location)
            .onAppear {
                let dir = documentDir
                    .appendingPathComponent("Restic")
                    .appendingPathComponent(name)
                repo.location = dir.path
            }
        HStack {
            Button("Select Directory") {
                NSApp.beginSavePanel { panel in
                    panel.setup(
                        title: "Create Restic Storage Space",
                        nameFieldStringValue: name,
                        directoryURL: documentDir.appendingPathComponent("Restic"),
                        canCreateDirectories: true,
                        showsHiddenFiles: false
                    )
                } completion: { repo.location = $0.path }
            }
            Spacer()
            Text("Edit Environment")
                .font(.footnote)
                .underline()
                .onTapGesture { openEnvironmentSetupPanel = true }
                .sheet(isPresented: $openEnvironmentSetupPanel) {
                    SetupEnvPanelView(repo: $repo)
                }
        }
        Text("Restic supports network storage like sftp or s3, see [document](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html) for more. To setup advanced repository scheme, fill the blank manually. We will initialize the repository for you.")
            .font(.footnote)
    }

    @ViewBuilder
    var deviceSetup: some View {
        Text("Select Device")
            .bold()
        Picker("Backup Device", selection: $udid) {
            ForEach(devManager.deviceList) { device in
                Text("\(device.deviceName) - \(device.udid)")
                    .tag(device.udid)
            }
        }
        .pickerStyle(.menu)
        .disabled(devManager.deviceList.isEmpty)
        .onAppear {
            if let id = devManager.deviceList.first?.udid { udid = id }
        }
    }

    func setup() {
        openProgress = true
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            var repo = repo
            let result = repo.initializeRepository()
            DispatchQueue.main.async {
                openProgress = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                switch result {
                case .success:
                    let plan = BackupPlan(name: name, deviceID: udid, resticRepo: repo)
                    bakManager.plans[plan.id] = plan
                    dismiss()
                case let .failure(failure):
                    print(failure)
                    var message = "Unknown Error"
                    if case let .error(msg) = failure {
                        message = msg
                    }
                    NSApp.alertError(message: message)
                }
            }
        }
    }
}

private struct SetupEnvPanelView: View {
    @Binding var repo: ResticRepo
    @Environment(\.dismiss) var dismiss

    @State var text = ""
    @State var errorLine: String? = nil

    var body: some View {
        SheetPanelView("Environment Variables (Optional)") {
            content.onChange(of: text) { _ in
                _ = convert(input: text)
            }
        }
        .background(Color("TextEditorBackground"))
    }

    func convert(value: [ResticRepo.EnvValue]) -> String {
        value
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
    }

    func convert(input: String) -> [ResticRepo.EnvValue] {
        errorLine = nil
        var ans = [ResticRepo.EnvValue]()
        for line in input.split(separator: "\n") {
            var comps = line.components(separatedBy: "=")
            guard comps.count > 1 else {
                errorLine = String(line)
                continue
            }
            let key = comps.removeFirst()
            let value = comps.joined(separator: "=")
            ans.append(.init(key: key, value: value))
        }
        return ans
    }

    @ViewBuilder
    var content: some View {
        Text("Environment variables here will be passed to restic.")
        TextEditor(text: $text)
            .monospaced()
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .border(Color.gray.opacity(0.5))
            .onAppear { text = convert(value: repo.metadata) }
            .onDisappear { repo.metadata = convert(input: text) }
        Group {
            Text("Eg: AWS_ACCESS_KEY_ID=xxxxxx")
            if let errorLine {
                Text("Error: \(errorLine)")
                    .foregroundStyle(.red)
                    .underline()
            } else {
                Text("RESTIC_REPOSITORY, RESTIC_PASSWORD will be ignored.")
                    .underline()
            }
        }
        .font(.footnote)
        .monospaced()
        .opacity(0.5)
    }
}

#Preview {
    CreateBackupPlanPanelView()
}
