import SwiftUI

@main
struct xethinfoApp: App {
    @StateObject private var CurrentState = EthernetStatus()
    
    var body: some Scene {
        MenuBarExtra("xethinfo", systemImage: CurrentState.EthernetIcon){
            VStack {
                Text("xethinfo").foregroundStyle(.secondary).padding(10)
                Text(CurrentState.EthernetStateString).padding(5)
                Divider()
                Text("Current network speed").foregroundStyle(.secondary).padding(5)
                HStack {
                    Text(CurrentState.DownloadString).frame(maxWidth: .infinity, alignment: .trailing)
                    Image(systemName: "arrow.down").hidden()
                    Image(systemName: "arrow.up").hidden()
                    Text(CurrentState.UploadString).frame(maxWidth: .infinity, alignment: .leading)
                }.overlay(
                    HStack {
                        Image(systemName: "arrow.down")
                        Image(systemName: "arrow.up")
                    }
                )
                Divider()
                Button("Quit"){
                    NSApplication.shared.terminate(nil)
                }.padding(5)
            }
            
            .onAppear() {
                CurrentState.startSpeedMon()
            }
            
            .onDisappear() {
                CurrentState.stopSpeedMon()
            }
        }
        .menuBarExtraStyle(.window);
    }
}
