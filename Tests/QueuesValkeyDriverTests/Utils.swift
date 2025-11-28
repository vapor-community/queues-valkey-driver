import Vapor

func valkeyHostname() -> String {
    Environment.get("VALKEY_HOSTNAME") ?? "localhost"
}

func valkeyPort() -> Int {
    Environment.get("VALKEY_PORT").map { Int($0) ?? 6379 } ?? 6379
}
