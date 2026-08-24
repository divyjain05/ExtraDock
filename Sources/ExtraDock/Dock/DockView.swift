import SwiftUI

/// The row of app icons shown in the expanded panel. Icons launch on tap and
/// can be dragged to reorder — the neighbours part to open a slot and spring
/// back into place, mirroring how the real macOS Dock rearranges.
struct DockView: View {
    let apps: [DockApp]
    let iconSize: CGFloat
    let spacing: CGFloat
    let onLaunch: (DockApp) -> Void
    let onReorder: ([DockApp]) -> Void

    // Local working copy so a drag can rearrange live without a round-trip
    // through the store on every frame. Kept in sync when `apps` changes
    // externally (add/remove via Settings or a Finder drop).
    @State private var ordered: [DockApp] = []
    // Which icon is being dragged, and how far — the icon tracks the cursor 1:1.
    @State private var draggingID: DockApp.ID?
    @State private var dragTranslation: CGFloat = 0
    // The slot the dragged icon would drop into right now; neighbours shift to
    // open it. Held as state so the parting motion can be spring-animated.
    @State private var insertion: Int = 0

    private var slot: CGFloat { iconSize + spacing }

    var body: some View {
        Group {
            if ordered.isEmpty {
                Text("Drop apps here via Settings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: spacing) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, app in
                        iconView(for: app, at: index)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .onAppear { ordered = apps }
        .onChange(of: apps) { ordered = $0 }
    }

    @ViewBuilder
    private func iconView(for app: DockApp, at index: Int) -> some View {
        let isDragging = app.id == draggingID
        Image(nsImage: iconImage(for: app))
            .resizable()
            .frame(width: iconSize, height: iconSize)
            .help(app.name)
            .scaleEffect(isDragging ? 1.12 : 1.0)
            .shadow(color: .black.opacity(isDragging ? 0.35 : 0), radius: isDragging ? 12 : 0, y: isDragging ? 6 : 0)
            .offset(x: offset(for: index))
            .zIndex(isDragging ? 1 : 0)
            // Neighbours animate as the insertion slot changes; the dragged
            // icon follows the cursor directly (no animation on its own offset).
            .animation(isDragging ? nil : .spring(response: 0.30, dampingFraction: 0.72), value: insertion)
            .animation(isDragging ? nil : .spring(response: 0.30, dampingFraction: 0.72), value: draggingID)
            .onTapGesture { onLaunch(app) }
            .gesture(dragGesture(for: app))
    }

    // The dragged icon follows the cursor; every other icon between the drag's
    // origin and the current insertion slot slides one slot aside to open a gap.
    private func offset(for index: Int) -> CGFloat {
        guard let from = ordered.firstIndex(where: { $0.id == draggingID }) else { return 0 }
        if index == from { return dragTranslation }
        let to = insertion
        if from < to, index > from, index <= to { return -slot }
        if from > to, index >= to, index < from { return slot }
        return 0
    }

    private func dragGesture(for app: DockApp) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if draggingID != app.id {
                    draggingID = app.id
                    insertion = ordered.firstIndex(where: { $0.id == app.id }) ?? 0
                }
                dragTranslation = value.translation.width
                guard let from = ordered.firstIndex(where: { $0.id == app.id }) else { return }
                let proposed = from + Int((dragTranslation / slot).rounded())
                insertion = min(max(proposed, 0), ordered.count - 1)
            }
            .onEnded { _ in
                guard let from = ordered.firstIndex(where: { $0.id == app.id }) else {
                    resetDrag()
                    return
                }
                let to = insertion
                var newOrder = ordered
                let moved = newOrder.remove(at: from)
                newOrder.insert(moved, at: to)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    ordered = newOrder
                    resetDrag()
                }
                if newOrder.map(\.id) != apps.map(\.id) {
                    onReorder(newOrder)
                }
            }
    }

    private func resetDrag() {
        draggingID = nil
        dragTranslation = 0
    }

    private func iconImage(for app: DockApp) -> NSImage {
        if let url = app.resolvedURL() {
            return AppIconProvider.icon(for: url)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
