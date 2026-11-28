import SwiftUI
import PhotosUI

struct IdeaEditorView: View {
    let idea: GiftIdea?
    let onSave: (IdeaDraft) async throws -> Void

    @EnvironmentObject private var templates: TemplateLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var draft: IdeaDraft
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isLoadingPhoto = false

    init(idea: GiftIdea?, onSave: @escaping (IdeaDraft) async throws -> Void) {
        self.idea = idea
        self.onSave = onSave

        if let idea = idea {
            _draft = State(initialValue: IdeaDraft(idea: idea))
        } else {
            _draft = State(initialValue: IdeaDraft())
        }

        // Show the photo the card already loaded.
        if let photoId = idea?.photoId {
            _previewImage = State(initialValue: PhotoCache.images.object(forKey: photoId as NSString))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("The idea") {
                    TextField("Gift name, e.g. Instant camera", text: $draft.title)
                    HStack {
                        Text("Estimated price")
                            .accessibilityHidden(true)
                        Spacer()
                        AmountField(title: "Estimated price", text: $draft.priceText, compact: true)
                    }
                }

                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(templates.content.giftCategories) { category in
                                categoryChip(category)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .listRowInsets(EdgeInsets())
                }

                Section("Photo") {
                    photoRow
                }

                Section("Product link") {
                    TextField("https://", text: $draft.link)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Why it's a good fit") {
                    TextField("Optional, a short reason", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle(idea == nil ? "Suggest an Idea" : "Edit Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(idea == nil ? "Add" : "Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(isLoadingPhoto)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var photoRow: some View {
        if let previewImage {
            Color.clear
                .frame(height: 190)
                .overlay {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        removePhoto()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel("Remove photo")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }

        PhotosPicker(selection: $pickerItem, matching: .images) {
            HStack {
                Label(previewImage == nil ? "Add a Photo" : "Change Photo", systemImage: "photo.on.rectangle.angled")
                if isLoadingPhoto {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .onChange(of: pickerItem) {
            loadPickedPhoto()
        }
    }

    private func loadPickedPhoto() {
        guard let pickerItem else { return }
        isLoadingPhoto = true

        Task {
            defer { isLoadingPhoto = false }

            guard let data = try? await pickerItem.loadTransferable(type: Data.self),
                  let jpeg = PhotoCompressor.jpeg(from: data) else {
                errorMessage = "That photo couldn't be used. Try another one."
                return
            }
            draft.photo = .set(jpeg)
            previewImage = UIImage(data: jpeg)
        }
    }

    private func removePhoto() {
        draft.photo = idea?.photoId == nil ? .keep : .remove
        previewImage = nil
        pickerItem = nil
    }

    private func categoryChip(_ category: GiftCategory) -> some View {
        let isSelected = draft.categoryKey == category.id

        return Button {
            draft.categoryKey = isSelected ? nil : category.id
        } label: {
            Label(category.title, systemImage: category.symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    isSelected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Color(.tertiarySystemFill)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft)
                dismiss()
            } catch {
                errorMessage = ErrorMessages.friendly(error)
            }
            isSaving = false
        }
    }
}
