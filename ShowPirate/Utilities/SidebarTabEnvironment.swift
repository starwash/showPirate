import SwiftUI

private struct SidebarTabIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var sidebarTabIsActive: Bool {
        get { self[SidebarTabIsActiveKey.self] }
        set { self[SidebarTabIsActiveKey.self] = newValue }
    }
}
