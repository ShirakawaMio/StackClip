//
//  ClipboardManager.swift
//  StackClip
//
//  Created by Shirakawa Mio on 03.06.2025.
//

import AppKit
import ApplicationServices
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let popFromStack = Self("popFromStack", default: .init(.v, modifiers: [.command, .option]))
}

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
    
    private var ignoreNextChange = false

    init() {
        self.changeCount = pasteboard.changeCount
        startMonitoringClipboard()
        registerHotKeys()
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
            #if DEBUG
            print("忽略了一次由自身写入触发的剪贴板变化")
            #endif
            return
        }
        if pasteboard.changeCount != changeCount {
            if let newItems = pasteboard.pasteboardItems {
                let snapshot = newItems.map { PasteboardItemData(item: $0) }
                if clipboardStack.first != snapshot {
                    clipboardStack.insert(snapshot, at: 0)
                    if clipboardStack.count > AppConfig.shared.maxStackDepth {
                        clipboardStack.removeLast()
                    }
                    #if DEBUG
                    print("Clipboard changed: new content added -> \(snapshot)")
                    print("Current clipboard stack: \(clipboardStack)")
                    #endif
                }
            }
            changeCount = pasteboard.changeCount
        }
    }

    private func registerHotKeys() {
        KeyboardShortcuts.onKeyUp(for: .popFromStack) {
            self.pasteTopElement(pop: true)
        }
    }

    private func pasteTopElement(pop: Bool) {
        guard !clipboardStack.isEmpty else { return }

        let elementToPasteData = clipboardStack.first!
        #if DEBUG
        print("pasteTopElement called with pop = \(pop). Pasting content: \(elementToPasteData)")
        #endif
        ignoreNextChange = true // 下次检测时跳过

        let newItems = elementToPasteData.map { $0.toPasteboardItem() }

        pasteboard.clearContents()
        pasteboard.writeObjects(newItems)

        // 动态计算延迟时间
        var delay: TimeInterval = AppConfig.shared.basePasteDelay

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
            delay = AppConfig.shared.basePasteDelay * 0.5
        } else if hasRTForHTMLOrImage && typeCount <= 2 {
            delay = AppConfig.shared.basePasteDelay * 1
        } else if typeCount > 2 {
            delay = AppConfig.shared.basePasteDelay * 2
        } else {
            // 其他情况保持默认
            delay = AppConfig.shared.basePasteDelay * 2
        }

        #if DEBUG
        print("simulatePaste 延迟时间设置为 \(delay) 秒")
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.simulatePaste()
        }

        if pop {
            clipboardStack.removeFirst()
            #if DEBUG
            print("Element popped from clipboard stack. Current stack: \(clipboardStack)")
            #endif
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
        #if DEBUG
        print("模拟粘贴事件已触发")
        #endif
    }
    

}
