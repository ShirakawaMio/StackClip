//
//  ClipboardManager.swift
//  StackClip
//
//  Created by Shirakawa Mio on 03.06.2025.
//

import AppKit
import HotKey
import ApplicationServices

class ClipboardManager: ObservableObject {
    var pasteboard = NSPasteboard.general
    private var changeCount: Int
    @Published var clipboardStack: [String] = []
    
    private var previewHotKey: HotKey?
    private var popHotKey: HotKey?
    private var ignoreNextChange = false

    init() {
        self.changeCount = pasteboard.changeCount
        startMonitoringClipboard()
        registerHotKeys()
        checkAccessibilityPermission()
    }

    private func startMonitoringClipboard() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkForChanges()
        }
    }

    private func checkForChanges() {
        if ignoreNextChange {
            ignoreNextChange = false
            changeCount = pasteboard.changeCount // 依然要同步 changeCount
            print("忽略了一次由自身写入触发的剪贴板变化")
            return
        }
        if pasteboard.changeCount != changeCount {
            if let newContent = pasteboard.string(forType: .string),
               clipboardStack.first != newContent {
                clipboardStack.insert(newContent, at: 0)
                print("Clipboard changed: new content added -> \(newContent)")
                print("Current clipboard stack: \(clipboardStack)")
            }
            changeCount = pasteboard.changeCount
        }
    }

    private func registerHotKeys() {
        // 不弹栈粘贴
        previewHotKey = HotKey(key: .v, modifiers: [.option, .shift])
        previewHotKey?.keyDownHandler = {
            self.pasteTopElement(pop: false)
        }
        if let previewKey = previewHotKey {
            print("Registered previewHotKey: key = v, modifiers = [option, shift]")
        }

        // 弹栈粘贴
        popHotKey = HotKey(key: .v, modifiers: [.command, .shift])
        popHotKey?.keyDownHandler = {
            self.pasteTopElement(pop: true)
        }
        if let popKey = popHotKey {
            print("Registered popHotKey: key = v, modifiers = [command, shift]")
        }
    }

    private func pasteTopElement(pop: Bool) {
        guard !clipboardStack.isEmpty else { return }

        let elementToPaste = clipboardStack.first!
        print("pasteTopElement called with pop = \(pop). Pasting content: \(elementToPaste)")
        ignoreNextChange = true // 下次检测时跳过

        pasteboard.clearContents()
        pasteboard.setString(elementToPaste, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // 小延时，保证剪贴板写入
            self.simulatePaste()
        }

        if pop {
            clipboardStack.removeFirst()
            print("Element popped from clipboard stack. Current stack: \(clipboardStack)")
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 'v'
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) // 'v'
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        print("模拟粘贴事件已触发")
    }
    
    private func checkAccessibilityPermission() {
        if !AXIsProcessTrusted() {
            print("【警告】未获得辅助功能权限。请在“系统设置 > 隐私与安全 > 辅助功能”中，勾选 StackClip。否则无法自动粘贴。")
        } else {
            print("辅助功能权限已获得。")
        }
    }
}
