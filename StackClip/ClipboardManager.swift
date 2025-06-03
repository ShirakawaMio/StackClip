//
//  ClipboardManager.swift
//  StackClip
//
//  Created by Shirakawa Mio on 03.06.2025.
//

import AppKit
import HotKey
import ApplicationServices

struct PasteboardItemData: Equatable, Hashable {
    let dataDict: [NSPasteboard.PasteboardType: Data]

    init(item: NSPasteboardItem) {
        var dict = [NSPasteboard.PasteboardType: Data]()
        for type in item.types {
            if let data = item.data(forType: type) {
                dict[type] = data
            }
        }
        self.dataDict = dict
    }
    
    func hash(into hasher: inout Hasher) {
        // 为确保唯一性，依赖类型名和内容
        hasher.combine(dataDict.count)
        for (type, data) in dataDict.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            hasher.combine(type.rawValue)
            hasher.combine(data)
        }
    }

    func toPasteboardItem() -> NSPasteboardItem {
        let newItem = NSPasteboardItem()
        for (type, data) in dataDict {
            newItem.setData(data, forType: type)
        }
        return newItem
    }
}

extension PasteboardItemData {
    var displayString: String? {
        // 优先尝试 public.utf8-plain-text
        if let data = dataDict[.string], let str = String(data: data, encoding: .utf8), !str.isEmpty {
            return str
        }
        // 其次尝试 public.rtf 作为富文本
        if let data = dataDict[.rtf], let str = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string, !str.isEmpty {
            return str
        }
        // 其它类型可按需扩展
        return nil
    }
}

class ClipboardManager: ObservableObject {
    var pasteboard = NSPasteboard.general
    private var changeCount: Int
    @Published var clipboardStack: [[PasteboardItemData]] = []
    
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
            if let newItems = pasteboard.pasteboardItems {
                let snapshot = newItems.map { PasteboardItemData(item: $0) }
                if clipboardStack.first != snapshot {
                    clipboardStack.insert(snapshot, at: 0)
                    print("Clipboard changed: new content added -> \(snapshot)")
                    print("Current clipboard stack: \(clipboardStack)")
                }
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

        let elementToPasteData = clipboardStack.first!
        print("pasteTopElement called with pop = \(pop). Pasting content: \(elementToPasteData)")
        ignoreNextChange = true // 下次检测时跳过

        let newItems = elementToPasteData.map { $0.toPasteboardItem() }

        pasteboard.clearContents()
        pasteboard.writeObjects(newItems)

        // 动态计算延迟时间
        var delay: TimeInterval = 0.5
        var reason = "默认延迟"

        // 统计所有类型
        var allTypes = Set<NSPasteboard.PasteboardType>()
        for item in elementToPasteData {
            for type in item.dataDict.keys {
                allTypes.insert(type)
            }
        }
        let typeCount = allTypes.count

        let hasRTForHTMLOrImage = allTypes.contains(.rtf) || allTypes.contains(.html) || allTypes.contains(.tiff)
        let onlyPlainText = (typeCount == 1 && allTypes.contains(.string))

        if onlyPlainText {
            delay = 0.05
            reason = "仅含纯文本内容"
        } else if hasRTForHTMLOrImage && typeCount <= 2 {
            delay = 0.25
            reason = "包含 RTF/HTML 或图片，类型数不超过2"
        } else if typeCount > 2 {
            delay = 0.5
            reason = "含超过两种类型的数据"
        } else {
            // 其他情况保持默认
            delay = 0.5
            reason = "其他情况，使用默认延迟"
        }

        print("simulatePaste 延迟时间设置为 \(delay) 秒，原因：\(reason)")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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
