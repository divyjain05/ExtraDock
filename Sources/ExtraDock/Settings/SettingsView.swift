import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extra Dock Apps")
                .font(.headline)

            List {
                ForEach(model.apps) { app in
                    HStack {
                        if let url = app.resolvedURL() {
                            Image(nsImage: AppIconProvider.icon(for: url))
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.name)
                        Spacer()
                        Button {
                            model.remove(app)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 220)

            HStack {
                Button("Add App…") {
                    model.presentAddAppPanel()
                }
                Spacer()
                Toggle("Launch at Login", isOn: $model.launchAtLogin)
            }

            HStack(spacing: 8) {
                Text("Size")
                Image(systemName: "app").imageScale(.small)
                Slider(
                    value: $model.iconSize,
                    in: Double(AppPreferences.minIconSize)...Double(AppPreferences.maxIconSize)
                )
                Image(systemName: "app").imageScale(.large)
            }

            Toggle("Show Menu Bar Icon", isOn: $model.showMenuBarIcon)
        }
        .padding(20)
        .frame(width: 380)
    }
}
