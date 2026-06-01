import Foundation
import ZIPFoundation
#if canImport(FoundationXML)
    import FoundationXML
#endif

/// Shared inventory import/export codec used by both the app and the share
/// extension: serialises to / parses from the lenient XML format, and reads or
/// writes ZIP archives wrapping that XML.
enum InventoryTransfer {

    // MARK: - Export

    /// The XML document for a set of furniture digests.
    static func xmlString(from digests: [FurnitureDigest]) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<inventory>\n"
        for furniture in digests {
            xml += "  <furniture name=\"\(escaped(furniture.name))\">\n"
            for thing in furniture.things {
                xml += "    <thing name=\"\(escaped(thing.name))\" quantity=\"\(thing.quantity)\"/>\n"
            }
            xml += "  </furniture>\n"
        }
        xml += "</inventory>\n"
        return xml
    }

    /// The XML document as UTF-8 data.
    static func xmlData(from digests: [FurnitureDigest]) -> Data {
        Data(xmlString(from: digests).utf8)
    }

    /// The ZIP archive (wrapping the XML) as data.
    static func zipData(from digests: [FurnitureDigest], baseName: String) -> Data? {
        guard let url = temporaryZipURL(from: digests, baseName: baseName) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Writes the XML to a temporary file and returns its URL, ready to share.
    static func temporaryXMLURL(from digests: [FurnitureDigest], fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard let data = xmlString(from: digests).data(using: .utf8) else { return nil }
        return (try? data.write(to: url, options: .atomic)) == nil ? nil : url
    }

    /// Writes the XML, zips it, and returns the archive URL. The XML is placed in
    /// a folder because `NSFileCoordinator(.forUploading)` reliably zips folders
    /// (a lone file may be returned unzipped) — Foundation-only, no ZIP writer.
    static func temporaryZipURL(from digests: [FurnitureDigest], baseName: String) -> URL? {
        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent(baseName, isDirectory: true)
        try? manager.removeItem(at: folder)
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            guard let data = xmlString(from: digests).data(using: .utf8) else { return nil }
            try data.write(to: folder.appendingPathComponent("\(baseName).xml"), options: .atomic)
        } catch {
            return nil
        }

        var coordinatorError: NSError?
        var result: URL?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinatorError) { zippedURL in
            let destination = manager.temporaryDirectory.appendingPathComponent("\(baseName).zip")
            try? manager.removeItem(at: destination)
            result = (try? manager.copyItem(at: zippedURL, to: destination)) == nil ? nil : destination
        }
        return result
    }

    // MARK: - Import

    /// Parses furniture digests from a file, dispatching on its extension
    /// (`xml`, `zip`, or a best-effort fallback).
    static func digests(fromFileAt fileURL: URL) -> [FurnitureDigest] {
        switch fileURL.pathExtension.lowercased() {
        case "xml":
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            return digests(fromXMLData: data)
        case "zip":
            return digests(fromZIPAt: fileURL)
        default:
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            return digests(fromData: data, suggestedName: fileURL.lastPathComponent)
        }
    }

    /// Parses furniture digests from raw data, trying XML then ZIP.
    static func digests(fromData data: Data, suggestedName: String?) -> [FurnitureDigest] {
        let xmlDigests = digests(fromXMLData: data)
        guard xmlDigests.isEmpty else { return xmlDigests }

        let zipDigests = digests(fromZIPData: data)
        guard zipDigests.isEmpty else { return zipDigests }

        return []
    }

    /// Parses the lenient inventory XML.
    static func digests(fromXMLData data: Data) -> [FurnitureDigest] {
        let delegate = InventoryXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        parser.parse()
        return InventoryMath.normalizedDigests(delegate.furnitures)
    }

    static func digests(fromZIPAt fileURL: URL) -> [FurnitureDigest] {
        guard let archive = try? Archive(url: fileURL, accessMode: .read, pathEncoding: nil) else { return [] }
        return digests(from: archive)
    }

    static func digests(fromZIPData data: Data) -> [FurnitureDigest] {
        guard let archive = try? Archive(data: data, accessMode: .read, pathEncoding: nil) else { return [] }
        return digests(from: archive)
    }

    private static func digests(from archive: Archive) -> [FurnitureDigest] {
        var collected: [FurnitureDigest] = []
        for entry in archive where entry.type == .file {
            guard URL(fileURLWithPath: entry.path).pathExtension.lowercased() == "xml" else { continue }
            var entryData = Data()
            guard (try? archive.extract(entry, consumer: { entryData.append($0) })) != nil else { continue }
            collected.append(contentsOf: digests(fromXMLData: entryData))
        }
        return InventoryMath.normalizedDigests(collected)
    }

    // MARK: - Helpers

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

/// Lenient XML parser accepting synonym tags for names and quantities.
private final class InventoryXMLParserDelegate: NSObject, XMLParserDelegate {
    private(set) var furnitures: [FurnitureDigest] = []

    private var currentFurnitureName = ""
    private var currentFurnitureFallbackText = ""
    private var currentThings: [ThingDigest] = []

    private var currentThingName = ""
    private var currentThingFallbackText = ""
    private var currentThingQuantity = 1

    private var insideFurniture = false
    private var insideThing = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName.lowercased() {
        case "furniture":
            insideFurniture = true
            currentFurnitureName = resolvedName(from: attributeDict)
            currentFurnitureFallbackText = ""
            currentThings = []
        case "thing":
            guard insideFurniture else { return }
            insideThing = true
            currentThingName = resolvedName(from: attributeDict)
            currentThingFallbackText = ""
            currentThingQuantity = resolvedQuantity(from: attributeDict)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideThing {
            currentThingFallbackText += string
        } else if insideFurniture {
            currentFurnitureFallbackText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName.lowercased() {
        case "thing":
            guard insideThing else { return }
            let name = InventoryMath.cleanedName(
                currentThingName.isEmpty ? currentThingFallbackText : currentThingName
            )
            if name.isEmpty == false, currentThingQuantity > 0 {
                currentThings.append(ThingDigest(name: name, quantity: currentThingQuantity))
            }
            insideThing = false
            currentThingName = ""
            currentThingFallbackText = ""
            currentThingQuantity = 1
        case "furniture":
            guard insideFurniture else { return }
            let name = InventoryMath.cleanedName(
                currentFurnitureName.isEmpty ? currentFurnitureFallbackText : currentFurnitureName
            )
            if name.isEmpty == false, currentThings.isEmpty == false {
                furnitures.append(FurnitureDigest(name: name, things: currentThings))
            }
            insideFurniture = false
            currentFurnitureName = ""
            currentFurnitureFallbackText = ""
            currentThings = []
        default:
            break
        }
    }

    private func resolvedName(from attributes: [String: String]) -> String {
        let candidates = [attributes["name"], attributes["title"], attributes["label"], attributes["identifier"]]
        return InventoryMath.cleanedName(candidates.compactMap { $0 }.first ?? "")
    }

    private func resolvedQuantity(from attributes: [String: String]) -> Int {
        let candidates = [attributes["quantity"], attributes["count"], attributes["qty"], attributes["amount"]]
        for candidate in candidates {
            guard let candidate,
                  let quantity = Int(candidate.trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }
            return quantity
        }
        return 1
    }
}
