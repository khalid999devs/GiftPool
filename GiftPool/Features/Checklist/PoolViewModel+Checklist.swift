import Foundation
import SwiftUI

extension PoolViewModel {

    // MARK: Derived

    var sortedTasks: [GiftTask] {
        tasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    var completedTaskCount: Int {
        tasks.filter(\.isDone).count
    }

    func canToggle(_ task: GiftTask) -> Bool {
        guard isActive else { return false }
        return isOwner || task.assignedToUid == uid
    }

    // MARK: Actions

    func saveTask(_ draft: TaskDraft, editing task: GiftTask?) async throws {
        try requireActivePool()
        let input = try draft.validated()

        if let taskId = task?.id {
            try await repository.updateTask(input, taskId: taskId, poolId: poolId)
        } else {
            let nextOrder = tasks.count
            try await repository.addTask(input, poolId: poolId, sortOrder: nextOrder)
        }
    }

    func setTask(_ task: GiftTask, done: Bool) async {
        guard let taskId = task.id, canToggle(task) else { return }

        await perform("task-\(taskId)") {
            try await repository.setTaskDone(done, taskId: taskId, poolId: poolId)
        }
    }

    func deleteTask(_ task: GiftTask) async {
        guard let taskId = task.id else { return }

        await perform("task-\(taskId)") {
            try requireActivePool()
            try await repository.deleteTask(taskId: taskId, poolId: poolId)
        }
    }

    func moveTasks(from source: IndexSet, to destination: Int) async {
        var reordered = sortedTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        let orderedIds = reordered.compactMap(\.id)

        await perform("reorder") {
            try requireActivePool()
            try await repository.reorderTasks(orderedIds, poolId: poolId)
        }
    }
}
