//
//  TaskListView.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import Combine
import SwiftUI

private class TaskRepresentable: ObservableObject, Identifiable {
    var id: ObjectIdentifier
    var object: AnyObject
    var cancellables: Set<AnyCancellable> = []

    init(object: some ObservableObject & Identifiable) {
        id = object.id
        self.object = object

        object.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var icon: String {
        if let task = object as? BackupTask {
            if task.executing { return "gear.circle.fill" }
            if !task.success { return "checkmark.circle.badge.xmark.fill" }
            return task.completed ? "checkmark.circle.fill" : "hourglass.circle.fill"
        }
        if let task = object as? BackupPlanTask {
            if task.isRunning { return "gear.circle.fill" }
            if !task.errors.isEmpty { return "checkmark.circle.badge.xmark.fill" }
            return task.completed ? "checkmark.circle.fill" : "hourglass.circle.fill"
        }
        return "target"
    }

    var iconColor: Color {
        if let task = object as? BackupTask {
            if task.executing { return .blue }
            if !task.success { return .red }
            return task.completed ? .green : .gray
        }
        if let task = object as? BackupPlanTask {
            if task.isRunning { return .blue }
            if !task.errors.isEmpty { return .red }
            return task.completed ? .green : .gray
        }
        return .orange
    }

    var iconRotated: Bool {
        if let task = object as? BackupTask {
            return task.executing
        }
        if let task = object as? BackupPlanTask {
            return task.isRunning
        }
        return false
    }

    var name: String {
        if let task = object as? BackupTask {
            return "Backup Task - \(task.config.device.deviceName)"
        }
        if let task = object as? BackupPlanTask {
            return "Backup Plan Task - \(task.context.plan.name)"
        }
        return "Unknown Task"
    }

    var progress: Progress {
        if let task = object as? BackupTask {
            return task.overall
        }
        if let task = object as? BackupPlanTask {
            return task.progress
        }
        return .init()
    }

    var comparableDate: Date {
        if let task = object as? BackupTask {
            return task.date
        }
        if let task = object as? BackupPlanTask {
            return task.created
        }
        assertionFailure()
        return Date(timeIntervalSince1970: 0)
    }
}

private struct TaskListItemView: View {
    @StateObject var task: TaskRepresentable

    @State var openDetailBackupTask: BackupTask?
    @State var openDetailBackupPlanTask: BackupPlanTask?

    @State var iconRotated: Bool = false
    var foreverAnimation: Animation {
        Animation.linear(duration: 1.0)
            .repeatForever(autoreverses: false)
    }

    func updateRotate() {
        iconRotated = task.iconRotated
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: task.icon)
                    .foregroundStyle(task.iconColor)
                    .rotationEffect(Angle(degrees: iconRotated ? 360 : 0.0))
                    .animation(iconRotated ? foreverAnimation : .default, value: iconRotated)
                    .onChange(of: task.progress) { _ in
                        updateRotate()
                    }
                    .onAppear { updateRotate() }
                Text(task.name)
                Spacer()
                Text("\(Int(task.progress.fractionCompleted * 100))%")
                    .monospaced()
            }
            ProgressView(
                value: Double(task.progress.completedUnitCount),
                total: Double(task.progress.totalUnitCount)
            )
            .progressViewStyle(.linear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let task = task.object as? BackupTask {
                openDetailBackupTask = task
            }
            if let task = task.object as? BackupPlanTask {
                openDetailBackupPlanTask = task
            }
        }
        .sheet(item: $openDetailBackupTask) { task in
            BackupTaskView(task: task)
        }
        .sheet(item: $openDetailBackupPlanTask) { task in
            BackupPlanTaskView(task: task)
        }
    }
}

struct TaskListView: View {
    @StateObject var backupManager = bakManager
    @State private var tasks: [TaskRepresentable] = []

    var body: some View {
        content
            .onAppear { rebuildTasks() }
            .onReceive(backupManager.objectWillChange) { _ in
                rebuildTasks()
            }
            .navigationTitle("Backup Task")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {} label: {
                        Label("", systemImage: "paperplane")
                    }
                }
                ToolbarItem {
                    Button {
                        backupManager.cleanCompletedTasks()
                    } label: {
                        Label("Clean Completed", systemImage: "wind.snow")
                    }
                    .disabled(backupManager.runningTaskCount <= 0)
                }
            }
    }

    @ViewBuilder
    var content: some View {
        if tasks.isEmpty {
            Text("You don't have any task.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(tasks) {
                        TaskListItemView(task: $0)
                        Divider()
                    }
                    Label("EOF - \(tasks.count) Tasks", systemImage: "text.append")
                        .font(.footnote)
                }
                .padding()
            }
        }
    }

    func rebuildTasks() {
        var tasks = [TaskRepresentable]()
        tasks.append(contentsOf: backupManager.tasks.map(TaskRepresentable.init))
        tasks.append(contentsOf: backupManager.planTasks.map(TaskRepresentable.init))
        tasks.sort { $0.comparableDate > $1.comparableDate }
        self.tasks = tasks
    }
}

#Preview {
    let plan = bakManager.plans.first!.value
    let device = devManager.devices[plan.deviceID]!
    bakManager.tasks.append(.init(config: .init(
        device: device,
        useNetwork: true,
        useStoreBase: URL(fileURLWithPath: "/tmp"),
        useIncrementBackup: true
    )))
    bakManager.planTasks.append(.init(plan: plan, device: device))
    return TaskListView()
        .frame(width: 500, height: 300)
}
