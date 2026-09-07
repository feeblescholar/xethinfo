import Combine
import Network

@MainActor
final class EthernetStatus: ObservableObject {
    @Published var EthernetStateString = "..."
    @Published var EthernetIcon = "questionmark.app.fill"

    private let NWMonitor = NWPathMonitor(requiredInterfaceType: .wiredEthernet)
    private let UpdateQueue = DispatchQueue(label: "EthernetMonitor")

    init() {
        StartNWMonitor()
    }

    private func StartNWMonitor() {
        NWMonitor.pathUpdateHandler = { path in
            Task { @MainActor in
                self.EthernetStateString = path.status == .satisfied ? "Ethernet is connected" : "Ethernet is disconnected"
                self.EthernetIcon = path.status == .satisfied ? "network" : "network.slash"
            }
        }

        NWMonitor.start(queue: UpdateQueue)
    }

    deinit {
        NWMonitor.cancel()
    }
}
