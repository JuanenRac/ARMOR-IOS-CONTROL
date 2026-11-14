// ARMOR-IOS-CONTROL - how many nodes of every kind there are and how many answer: the count of the status screen, the same as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation

/// One node, whatever its kind ("radar", "solar", "electrical", "alarm" or "hmi"), and whether it answers.
public struct CensusEntry: Equatable, Sendable {
    public let id: String
    public let family: String
    public let online: Bool
    public init(id: String, family: String, online: Bool) { self.id = id; self.family = family; self.online = online }
}

/// The nodes of one kind: how many answer out of how many there are.
public struct CensusFamily: Equatable, Sendable {
    public let family: String
    public let online: Int
    public let total: Int
}

/// The radar nodes arrive on the live status stream; every kind of node reports its health to the server. The census takes both: a node that is on the stream is counted with what the
/// stream says, one that only reports its health with what the health says, and one that is in both is online when either says so (and is counted once).
public struct NodeCensus: Equatable, Sendable {
    public let entries: [CensusEntry]

    public var total: Int { entries.count }
    public var online: Int { entries.filter { $0.online }.count }
    public var silent: [CensusEntry] { entries.filter { !$0.online } }

    private static let order = ["radar", "solar", "electrical", "alarm", "hmi"]

    public var families: [CensusFamily] {
        NodeCensus.order.compactMap { family in
            let members = entries.filter { $0.family == family }
            return members.isEmpty ? nil : CensusFamily(family: family, online: members.filter { $0.online }.count, total: members.count)
        }
    }

    public static func of(radar: [FieldNode], health: NodeHealthOverview?) -> NodeCensus {
        var known: [String: CensusEntry] = [:]
        for node in health?.nodes ?? [] { known[node.nodeId] = CensusEntry(id: node.nodeId, family: node.family, online: !node.silent) }
        for node in radar {
            let live = node.online && !node.stale
            let before = known[node.id]
            known[node.id] = CensusEntry(id: node.id, family: before?.family ?? "radar", online: live || (before?.online ?? false))
        }
        return NodeCensus(entries: known.values.sorted { $0.id < $1.id })
    }
}
