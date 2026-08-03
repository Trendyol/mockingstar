import Foundation
import QuickJSC

final class QJSRuntime {
    let memoryLimit: Int
    let stackLimit: Int
    let timeout: Duration

    private(set) var handle: UnsafeMutableRawPointer?

    init(memoryLimit: Int = 32 * 1024 * 1024,
         stackLimit: Int = 1024 * 1024,
         timeout: Duration = .seconds(2)) throws {
        self.memoryLimit = memoryLimit
        self.stackLimit = stackLimit
        self.timeout = timeout

        let timeoutMilliseconds = UInt64(timeout.components.seconds) * 1_000
            + UInt64(timeout.components.attoseconds / 1_000_000_000_000_000)
        handle = qjs_context_new(memoryLimit, stackLimit, UInt32(min(timeoutMilliseconds, UInt64(UInt32.max))))
        guard handle != nil else {
            throw QuickJSError.runtimeUnavailable
        }
    }

    deinit {
        shutdown()
    }

    func shutdown() {
        guard let handle else { return }
        qjs_context_free(handle)
        self.handle = nil
    }

    func reset() throws {
        guard let handle else { throw QuickJSError.runtimeUnavailable }
        qjs_context_reset(handle)
    }
}
