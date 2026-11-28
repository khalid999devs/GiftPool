import SwiftUI

// A grid of faces to choose from, with a live preview on top.
struct AvatarPickerView: View {
    let name: String
    let current: String?
    let onSave: (String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 16)]

    init(name: String, current: String?, onSave: @escaping (String?) async throws -> Void) {
        self.name = name
        self.current = current
        self.onSave = onSave
        _selection = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    preview

                    ForEach(AvatarLibrary.groups) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(group.title)
                                .font(.headline)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(group.ids, id: \.self) { id in
                                    option(id, in: group)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 16)
            }
            .background(Theme.background)
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(selection == current)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    // MARK: Pieces

    private var preview: some View {
        VStack(spacing: 12) {
            AvatarView(name: name, avatarId: selection, size: 104)
                .id(selection)
                .transition(.scale(scale: 0.85).combined(with: .opacity))

            Button("Use My Initials") {
                choose(nil)
            }
            .buttonStyle(SoftButtonStyle(tint: .secondary))
            .opacity(selection == nil ? 0 : 1)
            .disabled(selection == nil)
        }
        .frame(maxWidth: .infinity)
    }

    private func option(_ id: String, in group: AvatarLibrary.Category) -> some View {
        let isSelected = selection == id
        let number = (group.ids.firstIndex(of: id) ?? 0) + 1

        return Button {
            choose(id)
        } label: {
            AvatarView(name: name, avatarId: id, size: 64)
                .padding(4)
                .overlay {
                    Circle()
                        .stroke(isSelected ? Theme.coral : Color.clear, lineWidth: 3)
                }
                .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(group.title) avatar \(number)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Actions

    private func choose(_ id: String?) {
        withAnimation(.snappy(duration: 0.25)) {
            selection = id
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await onSave(selection)
                dismiss()
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
            isSaving = false
        }
    }
}

#Preview {
    AvatarPickerView(name: "Khalid", current: "cool-1") { _ in }
}
