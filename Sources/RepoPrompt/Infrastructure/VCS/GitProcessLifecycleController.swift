import Foundation

/// Tracks one git child's spawn/cancellation/termination lifecycle.
///
/// Cancellation intent may arrive before, during, or after the synchronous
/// spawn call. Intent that accrues while the launch call is in flight is
/// applied by `didSpawn` immediately after the spawn returns: the child is
/// terminated cooperatively and SIGKILL escalation is armed, so a cancelled
/// caller never waits on an unkillable child.
final class GitProcessLifecycleController: @unchecked Sendable {
    enum SpawnState: Equatable {
        case running
        case cancellationRequested
        case terminated
    }

    private let lock = NSLock()
    private var cancellationRequested = false
    private var target: GitProcessLifecycleTarget?
    private var terminated = false
    private var cancellationEscalationTask: Task<Void, Never>?

    func checkCancellationBeforeSpawn() throws {
        lock.lock()
        let shouldCancel = cancellationRequested
        lock.unlock()
        if shouldCancel {
            throw CancellationError()
        }
    }

    func didSpawn(
        target: GitProcessLifecycleTarget,
        terminationGrace: Duration
    ) -> SpawnState {
        lock.lock()
        if terminated {
            let wasCancelled = cancellationRequested
            lock.unlock()
            return wasCancelled ? .cancellationRequested : .terminated
        }

        self.target = target
        let shouldTerminate = cancellationRequested
        if shouldTerminate {
            armCancellationEscalationLocked(
                target: target,
                terminationGrace: terminationGrace
            )
        }
        lock.unlock()

        if shouldTerminate, target.isRunning {
            target.terminate()
        }
        return shouldTerminate ? .cancellationRequested : .running
    }

    func requestCancellation(terminationGrace: Duration) {
        lock.lock()
        cancellationRequested = true
        let target = terminated ? nil : self.target
        if let target {
            armCancellationEscalationLocked(
                target: target,
                terminationGrace: terminationGrace
            )
        }
        lock.unlock()

        if let target, target.isRunning {
            target.terminate()
        }
    }

    func shouldKeepNormalTimeout() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !cancellationRequested && !terminated
    }

    func cancellationErrorIfRequested() -> CancellationError? {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested ? CancellationError() : nil
    }

    func didTerminate() {
        lock.lock()
        terminated = true
        target = nil
        let escalationTask = cancellationEscalationTask
        cancellationEscalationTask = nil
        lock.unlock()
        escalationTask?.cancel()
    }

    private func armCancellationEscalationLocked(
        target: GitProcessLifecycleTarget,
        terminationGrace: Duration
    ) {
        guard cancellationEscalationTask == nil else { return }
        cancellationEscalationTask = Task.detached { [self] in
            do {
                try await Task.sleep(for: terminationGrace)
            } catch {
                return
            }
            sendCancellationKillIfNeeded(target: target)
        }
    }

    private func sendCancellationKillIfNeeded(target: GitProcessLifecycleTarget) {
        lock.lock()
        defer { lock.unlock() }
        guard cancellationRequested,
              !terminated,
              self.target === target,
              target.isRunning
        else {
            return
        }
        target.forceKill()
    }
}
