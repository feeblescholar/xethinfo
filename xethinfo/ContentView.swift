import SwiftUI

@main
struct xethinfoApp: App {
    @StateObject private var CurrentState = EthernetStatus()
    
    var body: some Scene {
        MenuBarExtra("xethinfo", systemImage: CurrentState.EthernetIcon){
            VStack {
                Text("xethinfo").padding(10)
                Divider()
                Text(CurrentState.EthernetStateString).padding(10)
                Divider()
                Button("Quit"){
                    NSApplication.shared.terminate(nil)
                }.padding(10)
            }
        }
        .menuBarExtraStyle(.window);
    }
}
