//
//  BackupPlanTaskItemView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import SwiftUI

struct BackupPlanTaskItemView: View {
    @StateObject var task: BackupPlanTask.TaskItem

    let justPreview: Bool
    init(task: BackupPlanTask.TaskItem, justPreview: Bool = false) {
        _task = .init(wrappedValue: task)
        self.justPreview = justPreview
    }

    var icon: String {
        if justPreview { return "target" }
        return switch task.progress {
        case .pending: "hourglass.circle.fill"
        case .doing: "gear.circle.fill"
        case .done: "checkmark.circle.fill"
        case .failed: "checkmark.circle.badge.xmark.fill"
        }
    }

    var color: Color {
        if justPreview { return .accent }
        return switch task.progress {
        case .pending: .orange
        case .doing: .blue
        case .done: .green
        case .failed: .red
        }
    }

    var title: String {
        task.name.title
    }

    @State var openBackupTask: BackupTask? = nil
    @State var iconRotated: Bool = false
    var foreverAnimation: Animation {
        Animation.linear(duration: 1.0)
            .repeatForever(autoreverses: false)
    }

    func updateRotate() {
        if case .doing = task.progress {
            iconRotated = true
        } else {
            iconRotated = false
        }
    }

    @ViewBuilder
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .rotationEffect(Angle(degrees: iconRotated ? 360 : 0.0))
                .animation(iconRotated ? foreverAnimation : .default, value: iconRotated)
                .onChange(of: task.progress) { _ in
                    updateRotate()
                }
                .onAppear { updateRotate() }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                    Spacer()
                    if let backupTask = task.assocatedObject as? BackupTask {
                        Text("View Detail")
                            .underline()
                            .foregroundStyle(.accent)
                            .onTapGesture { openBackupTask = backupTask }
                            .sheet(item: $openBackupTask) { BackupTaskView(task: $0) }
                    }
                }
                Group {
                    switch task.progress {
                    case let .doing(progress):
                        ProgressView(value: progress.fractionCompleted)
                            .progressViewStyle(.linear)
                        HStack {
                            Text(task.message)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(progress.fractionCompleted * 100))%")
                        }
                        .monospaced()
                        .font(.footnote)
                    default: Group {}
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        BackupPlanTaskItemView(task: .init(name: .setup, progress: .pending)).padding(8)
        Divider()
        BackupPlanTaskItemView(task: .init(name: .receiveBackup, progress: .doing(progress: .init()))).padding(8)
        Divider()
        BackupPlanTaskItemView(task: .init(name: .receiveApplicationPackage, progress: .done)).padding(8)
        Divider()
        BackupPlanTaskItemView(task: .init(name: .setupAnalyze, progress: .done)).padding(8)
        Divider()
        BackupPlanTaskItemView(task: .init(name: .receiveAnalyze, progress: .failed(reason: .unknow))).padding(8)
        Divider()
        BackupPlanTaskItemView(task: .init(name: .makingSnapshot, progress: .failed(reason: .previousFailure))).padding(8)
        Divider()
        BackupPlanTaskItemView(task: .init(name: .cleaning, progress: .failed(reason: .previousFailure))).padding(8)
        Divider()
        BackupPlanTaskItemView(task: .init(name: .verifyingBackup, progress: .failed(reason: .previousFailure))).padding(8)
    }

    .frame(width: 400)
}
