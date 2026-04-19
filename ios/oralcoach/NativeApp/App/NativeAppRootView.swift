import SwiftUI

struct NativeAppRootView: View {
  @StateObject private var shellState = NativeAppShellState()

  var body: some View {
    NativeAppTabRootView(selection: $shellState.selectedTab)
  }
}

#if DEBUG
struct NativeAppRootView_Previews: PreviewProvider {
  static var previews: some View {
    NativeAppRootView()
  }
}
#endif
