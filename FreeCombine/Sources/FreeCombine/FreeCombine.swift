import Foundation
public enum FreeCombine {
    public static var runningInPlayground: Bool {
        ProcessInfo.processInfo.environment["PLAYGROUND_COMMUNICATION_SOCKET"] != .none
    }
}
