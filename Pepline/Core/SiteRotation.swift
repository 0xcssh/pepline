import Foundation

/// One tappable zone of the body map: a site and a side.
struct SiteZone: Hashable, CaseIterable {
    var site: InjectionSite
    var side: BodySide

    static let allCases: [SiteZone] = InjectionSite.allCases.flatMap { site in
        BodySide.allCases.map { SiteZone(site: site, side: $0) }
    }
}

/// Where the user last injected, so the body map can show rotation at a
/// glance (PeptidePal heat map, MEDS rotation). Pepline shows the least
/// recently used zone; it does not tell anyone where they must inject.
enum SiteRotation {
    /// Last use of each zone, optionally for one compound only.
    static func lastUse(in journal: Journal, compoundID: Compound.ID? = nil) -> [SiteZone: Date] {
        var result: [SiteZone: Date] = [:]
        for dose in journal.doses {
            guard let site = dose.site, let side = dose.side else { continue }
            if let compoundID, dose.compoundID != compoundID { continue }
            let zone = SiteZone(site: site, side: side)
            if let known = result[zone], known >= dose.date { continue }
            result[zone] = dose.date
        }
        return result
    }

    /// Whole days since the zone was used, nil if never.
    static func daysSince(_ zone: SiteZone, lastUse: [SiteZone: Date], now: Date, calendar: Calendar) -> Int? {
        guard let date = lastUse[zone] else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day
    }

    /// A never-used zone first (in body order), otherwise the one used longest ago.
    static func leastRecent(lastUse: [SiteZone: Date]) -> SiteZone {
        if let unused = SiteZone.allCases.first(where: { lastUse[$0] == nil }) { return unused }
        return SiteZone.allCases.min { lastUse[$0]! < lastUse[$1]! }!
    }
}
