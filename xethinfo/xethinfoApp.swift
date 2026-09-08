import Combine
import Network
import Darwin
import Foundation

@MainActor
final class EthernetStatus: ObservableObject {
    @Published var EthernetStateString = "..."
    @Published var EthernetIcon = "questionmark.app.fill"
    @Published var DownloadString = "..."
    @Published var UploadString = "..."

    private let NWMonitor = NWPathMonitor(requiredInterfaceType: .wiredEthernet)
    private let NWSpeedMonitor = NetworkSpeedMonitor()
    private let UpdateQueue = DispatchQueue(label: "EthernetMonitor")
    
    init() {
        StartNWMonitor()
        
        NWSpeedMonitor.onSpeedUpdate = { [weak self] dl, ul in
            Task { @MainActor in
                self?.DownloadString = "\(ByteCountFormatter.string(fromByteCount: Int64(dl), countStyle: .binary))/s"
                self?.UploadString = "\(ByteCountFormatter.string(fromByteCount: Int64(ul), countStyle: .binary))/s"
            }
        }
    }

    private func StartNWMonitor() {
        
        NWMonitor.pathUpdateHandler = { path in
            Task {@MainActor in
                self.EthernetStateString = path.status == .satisfied ? "Ethernet is connected" : "Ethernet is disconnected"
                self.EthernetIcon = path.status == .satisfied ? "network" : "network.slash"
                self.NWSpeedMonitor.ethInterfaces = path.availableInterfaces.filter {$0.type == .wiredEthernet}.map {$0.name}
            }
        }

        NWMonitor.start(queue: UpdateQueue)
    }
    
    func startSpeedMon() {
        NWSpeedMonitor.startMonitoring()
    }
    
    func stopSpeedMon() {
        NWSpeedMonitor.stopMonitoring()
    }

    deinit {
        NWMonitor.cancel()
    }
}

class NetworkSpeedMonitor {
    public var onSpeedUpdate: ((UInt64, UInt64) -> Void)?
    public var ethInterfaces: [String] = []
    
    private var timer: Timer?
    private var lastReceived: UInt64 = 0
    private var lastSent: UInt64 = 0
    private var deltaReceived: UInt64 = 0
    private var deltaSent: UInt64 = 0
    
    func startMonitoring() {
        let initialMetrics = pollInterfaceSpeed()
        
        lastReceived = initialMetrics.received
        lastSent = initialMetrics.sent
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.25, repeats: true) { [weak self] _ in
            self?.calculateSpeed()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func calculateSpeed() {
        let currentSpeed = pollInterfaceSpeed()
        
        deltaReceived = currentSpeed.received - lastReceived
        deltaSent = currentSpeed.sent - lastSent
        
        lastReceived = currentSpeed.received
        lastSent = currentSpeed.sent
        
        onSpeedUpdate?(deltaReceived, deltaSent)
    }

    private func pollInterfaceSpeed() -> (received: UInt64, sent: UInt64) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0
        
        guard sysctl(&mib, u_int(mib.count), nil, &len, nil, 0) == 0 else {
            return (0, 0)
        }
        
        var buffer = [UInt8](repeating: 0, count: len)
        
        guard sysctl(&mib, u_int(mib.count), &buffer, &len, nil, 0) == 0 else {
            return (0, 0)
        }
        
        var bytesReceived: UInt64 = 0
        var bytesSent: UInt64 = 0
        
        buffer.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            
            var cursor = 0
            
            while cursor < len {
                let msgPtr = baseAddress.advanced(by: cursor)
                let header = msgPtr.assumingMemoryBound(to: if_msghdr2.self).pointee
                
                if header.ifm_type == UInt8(RTM_IFINFO2) {
                    let sdlPtr = msgPtr.advanced(by: MemoryLayout<if_msghdr2>.stride).assumingMemoryBound(to: sockaddr_dl.self)
                    let sdl = sdlPtr.pointee
                    
                    if sdl.sdl_family == UInt8(AF_LINK) {
                        
                        let name = withUnsafeBytes(of: sdl.sdl_data) { nameRawPtr -> String in
                            let nameData = Data(bytes: nameRawPtr.baseAddress!, count: Int(sdl.sdl_nlen))
                            
                            return String(data: nameData, encoding: .utf8) ?? ""
                        }

                        if ethInterfaces.contains(name) {
                            bytesReceived += header.ifm_data.ifi_ibytes
                            bytesSent += header.ifm_data.ifi_obytes
                        }
                    }
                }
                
                cursor += Int(header.ifm_msglen)
            }
        }
        
        return (bytesReceived, bytesSent)
    }
    
    deinit {
        stopMonitoring()
    }
}
