// Sources/ta/Pipeline/GraphExpander.swift
import Foundation

public struct GraphExpander {
    public static let hardDepthCap = 10

    public let index: NoteIndex
    public let archiveDirectory: URL
    public let logger: Logger

    public init(index: NoteIndex, archiveDirectory: URL, logger: Logger = .quiet) {
        self.index = index
        self.archiveDirectory = archiveDirectory
        self.logger = logger
    }

    public func expand(directHits: [SearchHit], depth: Int) throws -> [SearchHit] {
        let clamped = max(0, min(depth, Self.hardDepthCap))
        var seen: [NoteRef: SearchHit] = [:]
        var order: [NoteRef] = []

        logger.log("expand: \(directHits.count) direct hits, max depth \(clamped)")

        for hit in directHits {
            if seen[hit.note.ref] == nil {
                seen[hit.note.ref] = hit
                order.append(hit.note.ref)
            }
        }

        var frontier: [(ref: NoteRef, depth: Int, via: NoteRef)] = []
        for hit in directHits {
            for outgoing in hit.note.outgoingLinks {
                if seen[outgoing] == nil {
                    frontier.append((outgoing, 1, hit.note.ref))
                }
            }
        }

        while !frontier.isEmpty {
            let nextFrontier = frontier
            frontier = []
            let currentDepth = nextFrontier.first?.depth ?? 0
            logger.log("expand: depth \(currentDepth), frontier \(nextFrontier.count) candidates")
            for entry in nextFrontier {
                if seen[entry.ref] != nil { continue }
                if entry.depth > clamped { continue }
                let url = archiveDirectory.appendingPathComponent(entry.ref.filename)
                let note: ParsedNote
                do {
                    note = try NoteParser.parse(fileURL: url, index: index)
                } catch {
                    continue
                }
                let hit = SearchHit(note: note, depth: entry.depth, via: entry.via, snippet: nil)
                seen[entry.ref] = hit
                order.append(entry.ref)
                if entry.depth + 1 <= clamped {
                    for outgoing in note.outgoingLinks where seen[outgoing] == nil {
                        frontier.append((outgoing, entry.depth + 1, entry.ref))
                    }
                }
            }
        }

        logger.log("expand: \(order.count) total (\(directHits.count) direct + \(order.count - directHits.count) expanded)")
        return order.compactMap { seen[$0] }
    }
}
