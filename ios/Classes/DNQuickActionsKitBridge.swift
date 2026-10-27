// Copyright 2026 the quick_actions_kit contributors.
// SPDX-License-Identifier: Apache-2.0
import Foundation
import UIKit

private typealias Dispatcher = @convention(c) (Int64, Int32, UnsafePointer<CChar>) -> Void
private let dispatcherSlot: UnsafeMutablePointer<Int64> = {
    let value = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
    value.pointee = 0
    return value
}()
private var slotRegistered = false
private var listenersRegistered = false
private var session: Int64 = 0
private var listening = false
private var pendingActions: [String] = []

private func symbol<T>(_ name: String, _: T.Type) -> T? {
    guard let address = dlsym(dlopen(nil, RTLD_NOW), name) else { return nil }
    return unsafeBitCast(address, to: T.self)
}
private func json(_ value: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
          let text = String(data: data, encoding: .utf8) else { return "null" }
    return text
}
private func fire(_ token: Int64, _ kind: Int32, _ payload: String) {
    dispatchPrecondition(condition: .onQueue(.main))
    let address = dispatcherSlot.pointee
    guard address != 0 else { return }
    payload.withCString { unsafeBitCast(address, to: Dispatcher.self)(token, kind, $0) }
}
private func action(_ type: String) {
    guard !type.isEmpty else { return }
    if listening && dispatcherSlot.pointee != 0 { fire(0, 1, json(type)) }
    else {
        // Bounded startup buffer. Shortcut taps are untrusted navigation input.
        if pendingActions.count == 32 { pendingActions.removeFirst() }
        pendingActions.append(type)
    }
}

@_cdecl("DNQuickActionsKitInitialize")
public func DNQuickActionsKitInitialize(_ pointer: Int64, _ newSession: Int32) -> Int32 {
    guard Thread.isMainThread else { return 1 }
    typealias Register = @convention(c) (UnsafeMutablePointer<Int64>) -> Void
    typealias Connect = @convention(c) (@escaping @convention(block) (UIScene, UISceneSession, UIScene.ConnectionOptions) -> Void) -> Int64
    typealias Shortcut = @convention(c) (@escaping @convention(block) (UIWindowScene, UIApplicationShortcutItem) -> Bool) -> Int64
    guard let register = symbol("DNRegisterAsyncDispatcherSlot", Register.self),
          let addConnect = symbol("DNSceneEventsAddConnectListener", Connect.self),
          let addShortcut = symbol("DNSceneEventsAddShortcutItemListener", Shortcut.self) else { return 1 }
    // Fail closed if the framework cannot protect the callback across restart.
    if !slotRegistered { register(dispatcherSlot); slotRegistered = true }
    dispatcherSlot.pointee = pointer
    if newSession != 0 { session += 1; listening = false }
    if !listenersRegistered {
        listenersRegistered = true
        _ = addConnect { _, _, options in
            if let item = options.shortcutItem { action(item.type) }
        }
        _ = addShortcut { _, item in action(item.type); return true }
    }
    return 0
}

@_cdecl("DNQuickActionsKitRequest")
public func DNQuickActionsKitRequest(_ token: Int64, _ pointer: UnsafePointer<CChar>) -> Int32 {
    guard Thread.isMainThread else { return 1 }
    let text = String(cString: pointer) // Copy before the caller frees the buffer.
    let expectedSession = session
    DispatchQueue.main.async {
        guard expectedSession == session, dispatcherSlot.pointee != 0 else { return }
        do {
            guard let data = text.data(using: .utf8),
                  let request = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let operation = request["operation"] as? String else { throw NativeError("invalid_request", "Malformed request.") }
            switch operation {
            case "listen":
                listening = true
                fire(token, 0, "{}")
                let buffered = pendingActions
                pendingActions.removeAll()
                for type in buffered { action(type) }
                return
            case "stop": listening = false
            case "clear": UIApplication.shared.shortcutItems = []
            case "set":
                guard let items = request["payload"] as? [[String: Any]], items.count <= 4 else {
                    throw NativeError("too_many_shortcuts", "iOS accepts at most four dynamic items; static items also occupy launcher slots.")
                }
                var ids = Set<String>()
                let shortcuts = try items.map { item -> UIApplicationShortcutItem in
                    guard let type = item["type"] as? String, !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          ids.insert(type).inserted else { throw NativeError("invalid_shortcut", "Types must be unique and types/titles nonempty.") }
                    let icon = (item["icon"] as? String).map { UIApplicationShortcutIcon(templateImageName: $0) }
                    return UIApplicationShortcutItem(type: type, localizedTitle: title,
                        localizedSubtitle: item["subtitle"] as? String, icon: icon, userInfo: nil)
                }
                UIApplication.shared.shortcutItems = shortcuts
            default: throw NativeError("invalid_operation", "Unknown operation.")
            }
            fire(token, 0, "{}")
        } catch let error as NativeError {
            fire(token, 0, json(["error": ["code": error.code, "message": error.message]]))
        } catch {
            fire(token, 0, json(["error": ["code": "native_error", "message": "The shortcut operation failed."]]))
        }
    }
    return 0
}
private struct NativeError: Error {
    let code: String
    let message: String
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
}
