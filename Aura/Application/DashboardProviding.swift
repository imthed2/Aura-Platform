protocol DashboardProviding: Sendable {
    func dashboardSnapshot() async throws -> AuraDashboardSnapshot
}

struct MockDashboardProvider: DashboardProviding {
    let snapshot: AuraDashboardSnapshot

    init(snapshot: AuraDashboardSnapshot = AuraMockData.snapshot) {
        self.snapshot = snapshot
    }

    func dashboardSnapshot() async throws -> AuraDashboardSnapshot {
        snapshot
    }
}

