import SwiftUI

enum NativeMigrationConfig {
  // Turn this on once the Swift shell has enough ported functionality to replace RN.
  static let isEnabled = true
}

struct NativeMigrationRootView: View {
  var body: some View {
    NativeAppRootView()
  }
}
