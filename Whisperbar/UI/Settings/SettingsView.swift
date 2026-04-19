import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            HotkeyTab()
                .tabItem { Label("Hotkey", systemImage: "keyboard") }

            ModelTab()
                .tabItem { Label("Model", systemImage: "cpu") }

            StatsTab()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}
