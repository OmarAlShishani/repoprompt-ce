import Darwin
import Foundation

/// Minimal PID/process-group signal surface for one spawned git child.
///
/// Replaces Foundation `Process` in the git lifecycle and timeout controllers
/// so that launch, cancellation, and reaping never depend on NSTask state.
/// `posix_spawn` returns a fully valid PID synchronously, so a target is only
/// ever constructed for a child that actually exists.
final class GitProcessLifecycleTarget: @unchecked Sendable {
    let processIdentifier: pid_t
    let processGroupID: pid_t?

    private let lock = NSLock()
    private var terminated = false

    init(processIdentifier: pid_t, processGroupID: pid_t?) {
        self.processIdentifier = processIdentifier
        self.processGroupID = processGroupID
    }

    /// True until the reaper observes termination. A child that has exited but
    /// is not yet reaped still counts as running; signaling a zombie is a
    /// harmless no-op, matching the previous `Process.isRunning` usage where
    /// signals raced with termination.
    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !terminated && processIdentifier > 0
    }

    /// Marks the child as reaped. Later `terminate()`/`forceKill()` calls
    /// become no-ops so a reused PID can never be signaled.
    func markTerminated() {
        lock.lock()
        terminated = true
        lock.unlock()
    }

    /// Cooperative termination request (SIGTERM), process-group first.
    func terminate() {
        sendSignal(SIGTERM)
    }

    /// Forced termination (SIGKILL), process-group first.
    func forceKill() {
        sendSignal(SIGKILL)
    }

    private func sendSignal(_ signalValue: Int32) {
        lock.lock()
        let shouldSignal = !terminated && processIdentifier > 0
        lock.unlock()
        guard shouldSignal else { return }
        ProcessTermination.signalProcessGroupOrPID(
            pid: processIdentifier,
            processGroupID: processGroupID,
            signal: signalValue
        )
    }
}
