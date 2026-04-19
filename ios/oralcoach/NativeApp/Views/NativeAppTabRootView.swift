import SwiftUI

struct NativeAppTabRootView: View {
  @Binding var selection: NativeAppTab

  var body: some View {
    TabView(selection: $selection) {
      NavigationStack {
        ConversationFeatureRootView()
      }
      .tag(NativeAppTab.conversation)
      .tabItem {
        Label("Conversation", systemImage: "message.fill")
      }

      NavigationStack {
        NativeRecordsFeatureScreen()
      }
      .tag(NativeAppTab.records)
      .tabItem {
        Label("Records", systemImage: "book.closed.fill")
      }

      NavigationStack {
        NativeSettingsFeatureScreen()
      }
      .tag(NativeAppTab.settings)
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
    }
  }
}

#if DEBUG
struct NativeAppTabRootView_Previews: PreviewProvider {
  static var previews: some View {
    NativeAppTabRootView(selection: .constant(.conversation))
  }
}
#endif
