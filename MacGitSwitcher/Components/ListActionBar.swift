import SwiftUI

/// Wraps a list or table in the classic macOS bordered container with
/// small add/remove buttons attached underneath, as in Mail's Accounts pane.
struct ListWithActionBar<Content: View, AddButton: View>: View {
    let canRemove: Bool
    let remove: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let addButton: AddButton

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            HStack(spacing: 0) {
                addButton
                    .frame(width: 24, height: 22)
                Divider().frame(height: 14)
                Button(action: remove) {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 22)
                        .contentShape(Rectangle())
                }
                .disabled(!canRemove)
                .accessibilityLabel("Remove")
                Spacer()
            }
            .buttonStyle(.borderless)
            .background(.bar)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.separator)
        }
    }
}

/// The standard "+" button for ``ListWithActionBar``.
struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Add")
    }
}
