import Foundation

// Task擴展，添加超時功能
extension Task where Failure == Error {
    static func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // 添加實際操作任務
            group.addTask {
                return try await operation()
            }
            
            // 添加超時任務
            group.addTask {
                // 使用新版Swift並發API的休眠方法
                try await Task<Never, Never>.sleep(for: .seconds(seconds))
                throw TimeoutError(seconds: seconds)
            }
            
            // 等待第一個完成的任務
            let result = try await group.next()!
            
            // 取消所有其他任務
            group.cancelAll()
            
            return result
        }
    }
}

// 超時錯誤類型
class TimeoutError: Error {
    let seconds: TimeInterval
    
    init(seconds: TimeInterval) {
        self.seconds = seconds
    }
    
    var localizedDescription: String {
        return "操作超時 (\(Int(seconds))秒)"
    }
}