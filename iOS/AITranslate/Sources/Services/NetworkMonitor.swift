import Foundation
import Network
import SwiftUI

/// Observable network monitor for tracking online/offline status across the app
@MainActor
final class NetworkMonitor: ObservableObject {

    // MARK: - Singleton (optional, for global access)

    static let shared = NetworkMonitor()

    // MARK: - Published State

    /// Whether the device is currently connected to the internet
    @Published private(set) var isOnline: Bool = true

    /// Connection type (wifi, cellular, etc.)
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Connection Type

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown

        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wired: return "Wired"
            case .unknown: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    // MARK: - Private Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.sayitai.networkmonitor")

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = path.status == .satisfied

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }

                #if DEBUG
                print("[NetworkMonitor] Status: \(path.status == .satisfied ? "Online" : "Offline"), Type: \(self?.connectionType.displayName ?? "Unknown")")
                #endif
            }
        }
        monitor.start(queue: queue)
    }
}
