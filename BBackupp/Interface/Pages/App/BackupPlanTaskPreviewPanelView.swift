//
//  BackupPlanTaskPreviewPanelView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import SwiftUI

struct BackupPlanTaskPreviewPanelView: View {
    let plan: BackupPlan
    let planTask: BackupPlanTask?

    @StateObject var backupManager = bakManager

    @State var openPlanTask: BackupPlanTask? = nil

    init(plan: BackupPlan) {
        self.plan = plan
        if let device = devManager.devices[plan.deviceID] {
            planTask = .init(plan: plan, device: device)
        } else {
            planTask = nil
        }
    }

    let spacing: CGFloat = 16
    @Environment(\.dismiss) var dismiss

    var isPlanInvalidAtThisTime: Bool {
        if planTask == nil { return true }
        for task in backupManager.tasks {
            if task.config.device.udid == plan.deviceID { return true }
        }
        for planTask in backupManager.planTasks {
            if planTask.context.device.udid == plan.deviceID { return true }
        }
        return false
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                Text("Backup Preview").bold()
                Spacer()
            }
            .padding(spacing)
            Divider()
            VStack(alignment: .leading, spacing: spacing) {
                Group {
                    if planTask == nil {
                        invalid
                    } else {
                        preview
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(spacing)
            Divider()
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Begin") {
                    guard let planTask else { return }
                    backupManager.planTasks.append(planTask)
                    planTask.start()
                    openPlanTask = planTask
                }
                .buttonStyle(.borderedProminent)
                .disabled(planTask == nil)
                .sheet(item: $openPlanTask) { dismiss() } content: {
                    BackupPlanTaskView(task: $0)
                }
            }
            .padding(spacing)
        }
        .frame(width: 400)
    }

    @ViewBuilder
    var invalid: some View {
        VStack(spacing: spacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("This backup plan is not available at this time.")
                .bold()
                .frame(maxWidth: .infinity)
        }
        .padding()
    }

    @ViewBuilder
    var preview: some View {
        if let task = planTask {
            HStack {
                Text("\(task.title)")
                Spacer()
                Image(systemName: "list.clipboard")
            }
            .bold()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(task.tasks) {
                    BackupPlanTaskItemView(task: $0, justPreview: true)
                }
            }
        } else { Group {} }
    }
}

#Preview {
    BackupPlanTaskPreviewPanelView(plan: bakManager.plans.first!.value)
}
