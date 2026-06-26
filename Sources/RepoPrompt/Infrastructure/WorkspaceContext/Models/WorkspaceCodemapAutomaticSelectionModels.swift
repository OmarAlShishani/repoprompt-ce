import Foundation

final class WorkspaceCodemapAutomaticSelectionPublicationPermit: @unchecked Sendable, Equatable {
    private let lock = NSLock()
    private var current = true

    static func == (
        lhs: WorkspaceCodemapAutomaticSelectionPublicationPermit,
        rhs: WorkspaceCodemapAutomaticSelectionPublicationPermit
    ) -> Bool {
        lhs === rhs
    }

    func withCurrent<T>(_ body: () -> T) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard current else { return nil }
        return body()
    }

    func revoke() {
        lock.lock()
        current = false
        lock.unlock()
    }
}

final class WorkspaceCodemapAutomaticSelectionPublicationLease: @unchecked Sendable, Equatable {
    private let lock = NSLock()
    private var releaseAction: (@Sendable () async -> Void)?

    init(release: @escaping @Sendable () async -> Void) {
        releaseAction = release
    }

    static func == (
        lhs: WorkspaceCodemapAutomaticSelectionPublicationLease,
        rhs: WorkspaceCodemapAutomaticSelectionPublicationLease
    ) -> Bool {
        lhs === rhs
    }

    func release() async {
        let action = lock.withLock {
            let action = releaseAction
            releaseAction = nil
            return action
        }
        await action?()
    }

    deinit {
        let action = lock.withLock {
            let action = releaseAction
            releaseAction = nil
            return action
        }
        if let action {
            Task { await action() }
        }
    }
}

struct WorkspaceCodemapAutomaticSelectionSourceIdentity: Hashable {
    let rootEpoch: WorkspaceCodemapRootEpoch
    let fileID: UUID
    let catalogGeneration: UInt64
}

struct WorkspaceCodemapAutomaticSelectionTarget: Hashable {
    let rootEpoch: WorkspaceCodemapRootEpoch
    let fileID: UUID
    let catalogGeneration: UInt64
    let requestGeneration: UInt64
    let logicalPath: WorkspaceCodemapLogicalPresentationPath
}

enum WorkspaceCodemapAutomaticSelectionSourceIssue: Equatable {
    case outsideRootScope(WorkspaceCodemapAutomaticSelectionSourceIdentity)
    case notCataloged(WorkspaceCodemapAutomaticSelectionSourceIdentity)
    case notDemanded(WorkspaceCodemapAutomaticSelectionSourceIdentity)
    case pending(
        WorkspaceCodemapAutomaticSelectionSourceIdentity,
        WorkspaceCodemapArtifactDemandTicket
    )
    case unavailable(
        WorkspaceCodemapAutomaticSelectionSourceIdentity,
        WorkspaceCodemapArtifactDemandUnavailableReason
    )
    case staleCatalogGeneration(
        WorkspaceCodemapAutomaticSelectionSourceIdentity,
        currentCatalogGeneration: UInt64?
    )
}

enum WorkspaceCodemapAutomaticSelectionTargetIssue: Equatable {
    case notCataloged(rootEpoch: WorkspaceCodemapRootEpoch, fileID: UUID)
    case staleGeneration(
        rootEpoch: WorkspaceCodemapRootEpoch,
        fileID: UUID,
        requestGeneration: UInt64
    )
    case logicalPathUnavailable(rootEpoch: WorkspaceCodemapRootEpoch, fileID: UUID)
}

enum WorkspaceCodemapAutomaticSelectionPartialReason: Equatable {
    case graph(WorkspaceCodemapStoreSelectionGraphPartialReason)
    case source(WorkspaceCodemapAutomaticSelectionSourceIssue)
    case sourceDemandTimedOut(WorkspaceCodemapAutomaticSelectionSourceIdentity)
}

enum WorkspaceCodemapAutomaticSelectionIncompleteReason: Equatable {
    case graph(WorkspaceCodemapStoreSelectionGraphQueryIncompleteReason)
}

enum WorkspaceCodemapAutomaticSelectionPendingReason: Equatable {
    case sourceDemand(
        WorkspaceCodemapAutomaticSelectionSourceIdentity,
        WorkspaceCodemapArtifactDemandTicket
    )
    case sourceBusy(WorkspaceCodemapAutomaticSelectionSourceIdentity, attempts: Int)
    case candidateDemand(
        rootEpoch: WorkspaceCodemapRootEpoch,
        fileID: UUID,
        ticket: WorkspaceCodemapArtifactDemandTicket
    )
    case candidateBusy(rootEpoch: WorkspaceCodemapRootEpoch, fileID: UUID, attempts: Int)
    case manifestAdmission(rootEpoch: WorkspaceCodemapRootEpoch)
    case graphRebuild(rootEpoch: WorkspaceCodemapRootEpoch)
}

enum WorkspaceCodemapAutomaticSelectionUnavailableReason: Equatable {
    case noReadySources
    case candidate(
        rootEpoch: WorkspaceCodemapRootEpoch,
        fileID: UUID,
        reason: WorkspaceCodemapArtifactDemandUnavailableReason
    )
    case graph(WorkspaceCodemapStoreSelectionGraphQueryUnavailableReason)
}

enum WorkspaceCodemapAutomaticSelectionStaleReason: Equatable {
    case rootEpochNotCurrent(WorkspaceCodemapRootEpoch)
    case rootScopeChanged(WorkspaceCodemapRootEpoch)
    case sourceStateChanged(WorkspaceCodemapAutomaticSelectionSourceIdentity)
    case sourceCatalogGeneration(
        WorkspaceCodemapAutomaticSelectionSourceIdentity,
        currentCatalogGeneration: UInt64?
    )
    case targetStateChanged(WorkspaceCodemapAutomaticSelectionTargetIssue)
    case coverageProof(WorkspaceCodemapRootEpoch)
    case graph(WorkspaceCodemapStoreSelectionGraphQueryStaleReason)
    case publicationReceipt
}

enum WorkspaceCodemapAutomaticSelectionBudgetReason: Equatable {
    case sourceLimit(attempted: Int, limit: Int)
    case uniqueSourceLimit(attempted: Int, limit: Int)
    case sourceIssueLimit(attempted: Int, limit: Int)
    case rootLimit(attempted: Int, limit: Int)
    case candidateDemandLimit(attempted: Int, limit: Int)
    case targetLimit(attempted: Int, limit: Int)
    case resolutionLimit(attempted: Int, limit: Int)
    case referenceFailureLimit(attempted: Int, limit: Int)
    case byteLimit(attempted: Int, limit: Int)
    case accountingOverflow
    case graph(
        rootEpoch: WorkspaceCodemapRootEpoch,
        reason: WorkspaceCodemapStoreSelectionGraphQueryBudgetReason
    )
}

enum WorkspaceCodemapAutomaticSelectionCoverage: Equatable {
    case complete(WorkspaceCodemapProjectionCoverageProof)
    case partial(
        proof: WorkspaceCodemapProjectionCoverageProof,
        reasons: [WorkspaceCodemapAutomaticSelectionPartialReason]
    )
    case incomplete([WorkspaceCodemapAutomaticSelectionIncompleteReason])
    case pending([WorkspaceCodemapAutomaticSelectionPendingReason])
    case unavailable(WorkspaceCodemapAutomaticSelectionUnavailableReason)
    case stale(WorkspaceCodemapAutomaticSelectionStaleReason)
    case busy(WorkspaceCodemapStoreSelectionGraphQueryBusyReason)
    case budget(WorkspaceCodemapStoreSelectionGraphQueryBudgetReason)
}

enum WorkspaceCodemapAutomaticSelectionAggregateCoverage: Equatable {
    case complete([WorkspaceCodemapProjectionCoverageProof])
    case partial(
        proofs: [WorkspaceCodemapProjectionCoverageProof],
        reasons: [WorkspaceCodemapAutomaticSelectionPartialReason]
    )
    case incomplete([WorkspaceCodemapAutomaticSelectionIncompleteReason])
    case pending([WorkspaceCodemapAutomaticSelectionPendingReason])
    case unavailable(WorkspaceCodemapAutomaticSelectionUnavailableReason)
    case stale(WorkspaceCodemapAutomaticSelectionStaleReason)
    case busy(WorkspaceCodemapStoreSelectionGraphQueryBusyReason)
    case budget(WorkspaceCodemapAutomaticSelectionBudgetReason)
}

struct WorkspaceCodemapAutomaticSelectionRootResult: Equatable {
    let rootEpoch: WorkspaceCodemapRootEpoch
    let targets: [WorkspaceCodemapAutomaticSelectionTarget]
    let sourceIssues: [WorkspaceCodemapAutomaticSelectionSourceIssue]
    let targetIssues: [WorkspaceCodemapAutomaticSelectionTargetIssue]
    let coverage: WorkspaceCodemapAutomaticSelectionCoverage
    let graphTargetCount: Int
    let graphResolutionCount: Int
    let graphReferenceFailureCount: Int
    let graphByteCount: Int
    let graphKey: WorkspaceCodemapSelectionGraphRuntimeKey?

    init(
        rootEpoch: WorkspaceCodemapRootEpoch,
        targets: [WorkspaceCodemapAutomaticSelectionTarget],
        sourceIssues: [WorkspaceCodemapAutomaticSelectionSourceIssue],
        targetIssues: [WorkspaceCodemapAutomaticSelectionTargetIssue],
        coverage: WorkspaceCodemapAutomaticSelectionCoverage,
        graphTargetCount: Int = 0,
        graphResolutionCount: Int = 0,
        graphReferenceFailureCount: Int = 0,
        graphByteCount: Int = 0,
        graphKey: WorkspaceCodemapSelectionGraphRuntimeKey? = nil
    ) {
        self.rootEpoch = rootEpoch
        self.targets = targets
        self.sourceIssues = sourceIssues
        self.targetIssues = targetIssues
        self.coverage = coverage
        self.graphTargetCount = graphTargetCount
        self.graphResolutionCount = graphResolutionCount
        self.graphReferenceFailureCount = graphReferenceFailureCount
        self.graphByteCount = graphByteCount
        self.graphKey = graphKey
    }
}

struct WorkspaceCodemapAutomaticSelectionPublicationReceipt: Equatable {
    let requestID: UUID
    let rootScope: WorkspaceLookupRootScope
    let rootScopeEpochs: [WorkspaceCodemapRootEpoch]
    let sourceTickets: [WorkspaceCodemapArtifactDemandTicket]
    let graphKeys: [WorkspaceCodemapSelectionGraphRuntimeKey]
    let coverageProofs: [WorkspaceCodemapProjectionCoverageProof]
    let targets: [WorkspaceCodemapAutomaticSelectionTarget]
    let publicationPermit: WorkspaceCodemapAutomaticSelectionPublicationPermit
    let publicationLease: WorkspaceCodemapAutomaticSelectionPublicationLease?

    init(
        requestID: UUID,
        rootScope: WorkspaceLookupRootScope,
        rootScopeEpochs: [WorkspaceCodemapRootEpoch],
        sourceTickets: [WorkspaceCodemapArtifactDemandTicket],
        graphKeys: [WorkspaceCodemapSelectionGraphRuntimeKey],
        coverageProofs: [WorkspaceCodemapProjectionCoverageProof],
        targets: [WorkspaceCodemapAutomaticSelectionTarget],
        publicationPermit: WorkspaceCodemapAutomaticSelectionPublicationPermit,
        publicationLease: WorkspaceCodemapAutomaticSelectionPublicationLease? = nil
    ) {
        self.requestID = requestID
        self.rootScope = rootScope
        self.rootScopeEpochs = rootScopeEpochs
        self.sourceTickets = sourceTickets
        self.graphKeys = graphKeys
        self.coverageProofs = coverageProofs
        self.targets = targets
        self.publicationPermit = publicationPermit
        self.publicationLease = publicationLease
    }
}

enum WorkspaceCodemapAutomaticSelectionPublicationDisposition: Equatable {
    case current([WorkspaceCodemapAutomaticSelectionTarget])
    case stale(WorkspaceCodemapAutomaticSelectionStaleReason)
}

struct WorkspaceCodemapAutomaticSelectionCandidatePlan: Equatable {
    let candidates: [WorkspaceCodemapBindingAutomaticSelectionCatalogCandidate]
    let rootScopeEpochs: [WorkspaceCodemapRootEpoch]
    let coverageProofs: [WorkspaceCodemapProjectionCoverageProof]
}

struct WorkspaceCodemapAutomaticSelectionProvisionalCandidatePlan: Equatable {
    let candidates: [WorkspaceCodemapBindingAutomaticSelectionCatalogCandidate]
    let rootScopeEpochs: [WorkspaceCodemapRootEpoch]
    let incompleteReasons: [WorkspaceCodemapAutomaticSelectionIncompleteReason]
}

enum WorkspaceCodemapAutomaticSelectionCandidatePlanDisposition: Equatable {
    case ready(WorkspaceCodemapAutomaticSelectionCandidatePlan)
    case provisional(WorkspaceCodemapAutomaticSelectionProvisionalCandidatePlan)
    case incomplete([WorkspaceCodemapAutomaticSelectionIncompleteReason])
    case pending([WorkspaceCodemapAutomaticSelectionPendingReason])
    case busy(WorkspaceCodemapStoreSelectionGraphQueryBusyReason)
    case unavailable(WorkspaceCodemapAutomaticSelectionUnavailableReason)
    case stale(WorkspaceCodemapAutomaticSelectionStaleReason)
    case budget(WorkspaceCodemapAutomaticSelectionBudgetReason)
}

struct WorkspaceCodemapAutomaticSelectionResult: Equatable {
    let roots: [WorkspaceCodemapAutomaticSelectionRootResult]
    let aggregateCoverage: WorkspaceCodemapAutomaticSelectionAggregateCoverage
    let publicationReceipt: WorkspaceCodemapAutomaticSelectionPublicationReceipt?

    init(
        roots: [WorkspaceCodemapAutomaticSelectionRootResult],
        aggregateCoverage: WorkspaceCodemapAutomaticSelectionAggregateCoverage? = nil,
        publicationReceipt: WorkspaceCodemapAutomaticSelectionPublicationReceipt? = nil
    ) {
        self.roots = roots
        self.aggregateCoverage = if roots.isEmpty, let aggregateCoverage {
            aggregateCoverage
        } else {
            Self.aggregateCoverage(for: roots)
        }
        self.publicationReceipt = Self.validatedPublicationReceipt(
            publicationReceipt,
            coverage: self.aggregateCoverage
        )
    }

    var targets: [WorkspaceCodemapAutomaticSelectionTarget] {
        switch aggregateCoverage {
        case .complete, .partial:
            roots.flatMap(\.targets)
        case .incomplete, .pending, .unavailable, .stale, .busy, .budget:
            []
        }
    }

    private static func aggregateCoverage(
        for roots: [WorkspaceCodemapAutomaticSelectionRootResult]
    ) -> WorkspaceCodemapAutomaticSelectionAggregateCoverage {
        var proofs: [WorkspaceCodemapProjectionCoverageProof] = []
        var partial: [WorkspaceCodemapAutomaticSelectionPartialReason] = []
        for root in roots {
            switch root.coverage {
            case let .complete(proof):
                proofs.append(proof)
            case let .partial(proof, reasons):
                proofs.append(proof)
                partial.append(contentsOf: reasons)
            case let .incomplete(reasons):
                return .incomplete(reasons)
            case let .pending(reasons):
                return .pending(reasons)
            case let .unavailable(reason):
                return .unavailable(reason)
            case let .stale(reason):
                return .stale(reason)
            case let .busy(reason):
                return .busy(reason)
            case let .budget(reason):
                return .budget(.graph(rootEpoch: root.rootEpoch, reason: reason))
            }
        }
        return partial.isEmpty ? .complete(proofs) : .partial(proofs: proofs, reasons: partial)
    }

    private static func validatedPublicationReceipt(
        _ receipt: WorkspaceCodemapAutomaticSelectionPublicationReceipt?,
        coverage: WorkspaceCodemapAutomaticSelectionAggregateCoverage
    ) -> WorkspaceCodemapAutomaticSelectionPublicationReceipt? {
        guard let receipt,
              receipt.publicationPermit.withCurrent({ true }) == true
        else { return nil }
        let proofs: [WorkspaceCodemapProjectionCoverageProof]
        switch coverage {
        case let .complete(coverageProofs):
            proofs = coverageProofs
        case let .partial(coverageProofs, _):
            proofs = coverageProofs
        case .incomplete, .pending, .unavailable, .stale, .busy, .budget:
            return nil
        }
        return receipt.coverageProofs == proofs ? receipt : nil
    }
}
