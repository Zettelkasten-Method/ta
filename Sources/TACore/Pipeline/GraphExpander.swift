import Foundation

struct GraphExpander {
    static let hardDepthCap = 10

    let index: NoteIndex
    let archiveDirectory: URL
    let logger: Logger

    init(index: NoteIndex, archiveDirectory: URL, logger: Logger = .quiet) {
        self.index = index
        self.archiveDirectory = archiveDirectory
        self.logger = logger
    }

    func expand(directHits: [SearchHit], depth: Int) throws -> [SearchHit] {
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

        var frontier: [FrontierEntry] = []
        for hit in directHits {
            for outgoing in hit.note.outgoingLinks {
                if seen[outgoing] == nil {
                    frontier.append(FrontierEntry(ref: outgoing, via: hit.note.ref))
                }
            }
        }

        var level = 1
        while !frontier.isEmpty {
            let nextFrontier = frontier
            frontier = []
            logger.log("expand: depth \(level), frontier \(nextFrontier.count) candidates")
            for entry in nextFrontier {
                if seen[entry.ref] != nil { continue }
                if level > clamped { continue }
                let url = archiveDirectory.appending(path: entry.ref.filename)
                let note: ParsedNote
                do {
                    note = try NoteParser.parse(fileURL: url, index: index)
                } catch {
                    continue
                }
                let hit = SearchHit(note: note, depth: level, via: entry.via, snippet: nil)
                seen[entry.ref] = hit
                order.append(entry.ref)
                if level + 1 <= clamped {
                    for outgoing in note.outgoingLinks where seen[outgoing] == nil {
                        frontier.append(FrontierEntry(ref: outgoing, via: entry.ref))
                    }
                }
            }
            level += 1
        }

        logger.log("expand: \(order.count) total (\(directHits.count) direct + \(order.count - directHits.count) expanded)")
        return order.compactMap { seen[$0] }
    }

    private struct FrontierEntry {
        let ref: NoteRef
        let via: NoteRef
    }
}
