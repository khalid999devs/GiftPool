import SwiftUI

struct TaskRow: View {
    let task: GiftTask
    @Binding var isDone: Bool
    let assigneeName: String?
    let canToggle: Bool
    var isClosed = false

    var body: some View {
        HStack(spacing: 14) {
            Button {
                isDone.toggle()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Theme.success : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)
            .accessibilityLabel(isDone ? "Mark not done" : "Mark done")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)

                HStack(spacing: 10) {
                    if let assigneeName {
                        Label(assigneeName, systemImage: "person.fill")
                            .lineLimit(1)
                    }

                    if let dueDate = task.dueDate {
                        Label(DateHelpers.occasionText(dueDate, style: .dateTime.day().month(.abbreviated)), systemImage: "calendar")
                            .foregroundStyle(task.isOverdue() ? Theme.danger : .secondary)
                    }

                    if !canToggle && !isDone && !isClosed {
                        Image(systemName: "lock.fill")
                            .accessibilityLabel("Only the assignee or organizer can complete this")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .sensoryFeedback(.success, trigger: isDone) { _, newValue in newValue }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    List {
        TaskRow(
            task: GiftTask(id: "1", title: "Buy gift", assignedToUid: "a", dueDate: .now, isDone: true, sortOrder: 0),
            isDone: .constant(true),
            assigneeName: "You",
            canToggle: true
        )
        TaskRow(
            task: GiftTask(id: "2", title: "Wrap gift", assignedToUid: "b", dueDate: nil, isDone: false, sortOrder: 1),
            isDone: .constant(false),
            assigneeName: "Nadia",
            canToggle: false
        )
    }
}
