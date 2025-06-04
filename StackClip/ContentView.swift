//
//  ContentView.swift
//  StackClip
//
//  Created by Shirakawa Mio on 03.06.2025.
//

import SwiftUI
import AppKit

class SettingsViewModel: ObservableObject {
    @Published var hasAccessibilityPermission: Bool = false
    @Published var pasteDelay: Double = 0.15
    let pasteShortcut: String = "⌘⇧V"

    init() {
        self.hasAccessibilityPermission = Self.checkAccessibilityPermission()
    }

    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var clipboardManager: ClipboardManager

    var body: some View {
        Form {
            Section(header: Text("辅助功能权限")) {
                if viewModel.hasAccessibilityPermission {
                    Label("已获得辅助功能权限", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .padding(.leading)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("需要辅助功能权限以启用快捷粘贴", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Button("前往授权") {
                            viewModel.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(0.1)

            Section(header: Text("快捷键")) {
                HStack {
                    Text("弹栈粘贴")
                    Spacer()
                    Text(viewModel.pasteShortcut)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.leading)
            }
            .padding(0.1)

            Section(header: Text("粘贴延迟")) {
                VStack(alignment: .leading) {
                    HStack {
                        Slider(
                            value: $viewModel.pasteDelay,
                            in: 0.05...0.5,
                            step: 0.05
                        )
                        .offset(x:20)
                        .onChange(of: viewModel.pasteDelay) { _ in
                            clipboardManager.basePasteDelay = viewModel.pasteDelay
                        }
                        Text(String(format: "%.2f 秒", viewModel.pasteDelay))
                            .frame(width: 64, alignment: .trailing)
                    }
                    Text("设置粘贴操作的延迟时间，适用于部分应用粘贴兼容性问题。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading)
                }
            }
            .padding(0.1)
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            // 刷新权限状态
            viewModel.hasAccessibilityPermission = SettingsViewModel.checkAccessibilityPermission()
            clipboardManager.basePasteDelay = viewModel.pasteDelay
        }
    }
}

#Preview {
    ContentView().environmentObject(ClipboardManager())
}
