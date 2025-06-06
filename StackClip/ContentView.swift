//
//  ContentView.swift
//  StackClip
//
//  Created by Shirakawa Mio on 03.06.2025.
//

import SwiftUI
import AppKit
import KeyboardShortcuts

class SettingsViewModel: ObservableObject {
    @Published var hasAccessibilityPermission: Bool = false
    @Published var pasteDelay: Double = AppConfig.shared.basePasteDelay
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
    @ObservedObject var config = AppConfig.shared
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 100
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("辅助功能权限").font(.headline)
                    if viewModel.hasAccessibilityPermission {
                        Label("已获得辅助功能权限", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .padding(.leading)
                    } else {
                        HStack(spacing: 8) {
                                Button("前往授权") {
                                    viewModel.requestAccessibilityPermission()
                                }
                                .buttonStyle(.borderedProminent)
                            Label("需要辅助功能权限以启用快捷粘贴", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .padding(.leading)
                        }
                        .padding(.leading)
                    }
                }
                .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷键").font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        KeyboardShortcuts.Recorder("弹栈粘贴", name: .popFromStack)
                    }
                    .padding(.leading)
                }
                .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("粘贴延迟").font(.headline)
                    VStack(alignment: .leading) {
                        HStack {
                            Slider(
                                value: $config.basePasteDelay,
                                in: 0.05...0.5,
                                step: 0.05
                            )
                            .offset(x:20)
                            Text(String(format: "%.2f 秒", config.basePasteDelay))
                                .frame(width: 64, alignment: .trailing)
                        }
                        Text("设置粘贴操作的延迟时间，适用于部分应用粘贴兼容性问题。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                    }
                }
                .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("最大栈深度").font(.headline)
                    VStack(alignment: .leading) {
                        HStack {
                            Stepper(value: $config.maxStackDepth, in: 1...50) {
                                Text("栈深度")
                            }
                            TextField("", value: $config.maxStackDepth, formatter: numberFormatter)
                                .frame(width: 50)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .multilineTextAlignment(.center)
                        }
                        .padding(.leading)
                        Text("上限为 50，超出部分将被移除。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                    }
                }
                .padding(.bottom, 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text("显示").font(.headline)
                    HStack {
                        Text("显示程序坞图标")
                        Toggle("", isOn: $config.showDockIcon)
                            .labelsHidden()
                    }
                    .padding(.leading)
                  Text("关闭后应用将仅显示在菜单栏中。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading)
                    HStack {
                        Stepper(value: $config.maxTextLength){
                            Text("每行最多字符数")
                        }.padding(.leading)
                        TextField("", value: $config.maxTextLength, formatter: numberFormatter)
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.center)
                    }
                    Text("限制菜单中每个剪贴板元素最多预览字符数，上限为 64，64以上表示无限制")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading)
                }
                .padding(.bottom, 12)
            }
            .padding()
            .frame(width: 400)
        }
        .onAppear {
            // 刷新权限状态
            viewModel.hasAccessibilityPermission = SettingsViewModel.checkAccessibilityPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApplication.shared.windows.first(where: { $0.contentView is NSHostingView<ContentView> }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(ClipboardManager())
}
