// Sources/ta/Pipeline/GraphExpander.swift
import Foundation

public struct GraphExpander {
    public static let hardDepthCap = 10

    public let index: NoteIndex
    public let archiveDirectory: URL

    public init(index: NoteIndex, archiveDirectory: URL) {
        self.index = index
        self.archiveDirectory = archiveDirectory
    }

    public func expand(directHits: [SearchHit], depth: Int) throws -> [SearchHit] {
        let clamped = max(0, min(depth, Self.hardDepthCap))
        var seen: [NoteRef: SearchHit] = [:]
        var order: [NoteRef] = []

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

        return order.compactMap { seen[$0] }
    }
}
