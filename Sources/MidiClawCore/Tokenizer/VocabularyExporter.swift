import Foundation

/// Exports the MidiToken vocabulary to various formats for use in the
/// adapter training pipeline.
public struct VocabularyExporter {
    public init() {}

    /// Export the full vocabulary as a JSON file at the given path.
    public func exportJSON(to url: URL) throws {
        let data = try TokenVocabulary.exportVocabularyJSON()
        try data.write(to: url, options: .atomic)
    }

    /// Export as a simple text file (one token per line: "id\tname\tclass").
    public func exportTSV(to url: URL) throws {
        let vocab = TokenVocabulary.exportVocabulary()
        let lines = vocab.map { "\($0.id)\t\($0.name)\t\($0.tokenClass)" }
        let content = lines.joined(separator: "\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
