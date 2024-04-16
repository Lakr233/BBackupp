//
//  BackupPlanTaskView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import SwiftUI

struct BackupPlanTaskView: View {
    @StateObject var task: BackupPlanTask

    let spacing: CGFloat = 16

    var footnote: String {
        "\(task.id)"
    }

    @State var openTerminateAlert = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Backup Plan Task").bold()
                Spacer()
                if task.completed {
                    if task.errors.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "checkmark.circle.badge.xmark.fill")
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("\(Int(task.progress.fractionCompleted * 100))%")
                }
            }
            .padding(spacing)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(spacing)
            Divider()
            HStack {
                Text(footnote)
                    .font(.footnote)
                    .opacity(0.5)
                Spacer()
                if task.isRunning {
                    Button("Terminate") { openTerminateAlert = true }
                        .alert(isPresented: $openTerminateAlert) {
                            Alert(
                                title: Text("Are you sure you want to terminate this backup?"),
                                primaryButton: .destructive(Text("Terminate")) { task.terminate() },
                                secondaryButton: .cancel()
                            )
                        }
                }
                Button(task.completed ? "Done" : "Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(spacing)
        }
        .frame(width: 450)
    }

    @ViewBuilder
    var content: some View {
//        ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(task.tasks) { task in
                BackupPlanTaskItemView(task: task)
            }
        }
//        }
//        .frame(height: 250)
    }
}

#Preview {
    let plan = bakManager.plans.first!.value
    let task = BackupPlanTask(
        plan: plan,
        device: devManager.devices[plan.deviceID]!
    )
    return BackupPlanTaskView(task: task)
}
