//
//  StackClipApp.swift
//  StackClip
//
//  Created by Shirakawa Mio on 03.06.2025.
//

import SwiftUI

@main
struct ClipboardStackApp: App {
    @StateObject private var clipboardManager = ClipboardManager()

    var body: some Scene {
        MenuBarExtra("Clipboard", systemImage: "doc.on.clipboard") {
            if clipboardManager.clipboardStack.isEmpty {
                Text("剪贴板为空")
            } else {
                ForEach(clipboardManager.clipboardStack, id: \.self) { item in
                    Button(action: {
                        clipboardManager.copyToClipboard(item)
                    }) {
                        Text(item).lineLimit(1)
                    }
                }

                Divider()

                Button("清空栈") {
                    clipboardManager.clearStack()
                }
            }
        }
    }
}

extension ClipboardManager {
    func copyToClipboard(_ content: String) {
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    func clearStack() {
        clipboardStack.removeAll()
    }
}
