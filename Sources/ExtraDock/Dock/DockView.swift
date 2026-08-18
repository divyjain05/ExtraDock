import SwiftUI

struct DockView: View {
    let apps: [DockApp]
    let iconSize: CGFloat
    let onLaunch: (DockApp) -> Void

    var body: some View {
        HStack(spacing: 14) {
            if apps.isEmpty {
                Text("Drop apps here via Settings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(apps) { app in
                    if let url = app.resolvedURL() {
                        Image(nsImage: AppIconProvider.icon(for: url))
                            .resizable()
                            .frame(width: iconSize, height: iconSize)
                            .help(app.name)
                            .onTapGesture { onLaunch(app) }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
