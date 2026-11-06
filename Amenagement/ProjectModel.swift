import Foundation
import Observation
import SwiftUI

/// Prototype paramétrique en millimètres. Les valeurs initiales sont des exemples,
/// pas des mesures validées d'un Nissan Qashqai.
@Observable
final class ProjectModel {
    var vehicleName = "Nissan Qashqai — à préciser" { didSet { persist() } }
    var useCase = "Ranger mon matériel de travail" { didSet { persist() } }
    var seatsFolded = true { didSet { persist() } }
    var width = 1_050.0 { didSet { persist() } }
    var length = 900.0 { didSet { persist() } }
    var height = 320.0 { didSet { persist() } }
    var thickness = 15.0 { didSet { persist() } }
    var materialName = "Contreplaqué bouleau" { didSet { persist() } }
    var dividerCount = 1 { didSet { persist() } }
    var scanFileURL: URL? { didSet { persist() } }
    var scanBounds: ScanBounds? { didSet { persist() } }
    var scanDate: Date? { didSet { persist() } }
    var measurementsConfirmed = false { didSet { persist() } }
    var scanMeasurements: [String: [Double]] = [:] { didSet { persist() } }
    var openings: [OpeningFeature] = [OpeningFeature.defaultDrawer] { didSet { persist() } }
    var vehicleLandmarks: [VehicleLandmark] = [] { didSet { persist() } }
    var scanQuality: ScanQuality? { didSet { persist() } }

    init() {
        guard let data = try? Data(contentsOf: Self.projectFile),
              let saved = try? JSONDecoder().decode(SavedProject.self, from: data) else { return }
        vehicleName = saved.vehicleName
        useCase = saved.useCase ?? "Ranger mon matériel de travail"
        seatsFolded = saved.seatsFolded
        width = saved.width
        length = saved.length
        height = saved.height
        thickness = saved.thickness
        materialName = saved.materialName
        dividerCount = saved.dividerCount
        scanFileURL = saved.scanFileURL
        scanBounds = saved.scanBounds
        scanDate = saved.scanDate
        measurementsConfirmed = saved.measurementsConfirmed
        scanMeasurements = saved.scanMeasurements
        openings = saved.openings ?? [.defaultDrawer]
        vehicleLandmarks = saved.vehicleLandmarks ?? []
        scanQuality = saved.scanQuality
    }

    func applyScan(fileURL: URL, bounds: ScanBounds, quality: ScanQuality) {
        scanFileURL = fileURL
        scanBounds = bounds
        scanQuality = quality
        scanDate = .now
        // ARKit extents are useful starting estimates, but do not assume they are
        // manufacturing dimensions; the user reviews and edits each value.
        width = bounds.widthMM
        length = bounds.lengthMM
        height = bounds.heightMM
        measurementsConfirmed = false
        scanMeasurements = [:]
        vehicleLandmarks = []
    }

    func placeLandmark(_ kind: VehicleLandmarkKind, at position: SIMD3<Float>) {
        vehicleLandmarks.removeAll { $0.kind == kind }
        vehicleLandmarks.append(VehicleLandmark(kind: kind, x: position.x, y: position.y, z: position.z))
        measurementsConfirmed = false
    }

    func removeLandmark(_ kind: VehicleLandmarkKind) {
        vehicleLandmarks.removeAll { $0.kind == kind }
    }

    func hasLandmark(_ kind: VehicleLandmarkKind) -> Bool {
        vehicleLandmarks.contains { $0.kind == kind }
    }

    /// Proposition initiale par règles, à contrôler dans la vue 3D et dans le véhicule.
    func proposeWorkStorage(style: SuggestedStyle = .drawers, zoneCount: Int = 2) {
        let count = min(4, max(1, zoneCount))
        dividerCount = max(0, count - 1)
        guard style != .openCompartments else {
            openings = []
            return
        }
        let bayWidth = max(0, (innerWidth - Double(count - 1) * thickness - 12) / Double(count))
        let drawerDepth = max(0, length - 2 * thickness - 20)
        openings = (0..<count).map { index in
            let type: OpeningType = switch style {
            case .drawers: .drawer
            case .hingedDoors: .hingedDoor
            case .mixed: index.isMultiple(of: 2) ? .drawer : .hingedDoor
            case .openCompartments: .drawer
            }
            return OpeningFeature(name: type == .drawer ? "Tiroir \(index + 1)" : "Porte \(index + 1)",
                type: type, side: .rear, direction: type == .drawer ? .outward : .left,
                widthMM: bayWidth, heightMM: max(80, height * 0.42), travelMM: drawerDepth,
                clearanceMM: 2, hardware: type == .drawer ? "Glissières à sélectionner selon la charge" : "Charnières à sélectionner", openingAngle: 90)
        }
    }

    func recordMeasurement(_ valueMM: Double, for kind: MeasurementKind) {
        var values = scanMeasurements[kind.rawValue, default: []]
        values.append(valueMM)
        scanMeasurements[kind.rawValue] = values
        let sorted = values.sorted()
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        switch kind {
        case .moduleWidth: width = median
        case .moduleLength: length = median
        case .moduleHeight: height = median
        }
        measurementsConfirmed = false
    }

    func measurementSummary(for kind: MeasurementKind) -> (median: Double, count: Int, spread: Double)? {
        guard let values = scanMeasurements[kind.rawValue], !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        return (median, values.count, sorted.last! - sorted.first!)
    }

    var innerWidth: Double { max(0, width - 2 * thickness) }
    var wallHeight: Double { max(0, height - thickness) }
    var dividerPositions: [Double] {
        guard dividerCount > 0 else { return [] }
        return (1...dividerCount).map { length * Double($0) / Double(dividerCount + 1) }
    }

    var cutList: [CutPart] {
        let w = innerWidth
        let h = wallHeight
        let carcass = [
            CutPart(name: "Fond", quantity: 1, width: width, length: length, thickness: thickness, material: materialName),
            CutPart(name: "Côtés", quantity: 2, width: length, length: h, thickness: thickness, material: materialName),
            CutPart(name: "Façades", quantity: 2, width: w, length: h, thickness: thickness, material: materialName)
        ] + (dividerCount > 0 ? [CutPart(name: "Cloisons", quantity: dividerCount, width: w, length: h, thickness: thickness, material: materialName)] : [])
        let drawerParts = openings.filter { $0.type == .drawer }.flatMap { opening -> [CutPart] in
            let drawerWidth = max(0, opening.widthMM - 2 * opening.clearanceMM)
            let drawerHeight = max(0, opening.heightMM - thickness)
            let drawerDepth = max(0, opening.travelMM)
            return [
                CutPart(name: "\(opening.name) — fond", quantity: 1, width: max(0, drawerWidth - 2 * thickness), length: max(0, drawerDepth - 2 * thickness), thickness: thickness, material: materialName),
                CutPart(name: "\(opening.name) — côtés", quantity: 2, width: drawerDepth, length: drawerHeight, thickness: thickness, material: materialName),
                CutPart(name: "\(opening.name) — traverse avant", quantity: 1, width: max(0, drawerWidth - 2 * thickness), length: drawerHeight, thickness: thickness, material: materialName),
                CutPart(name: "\(opening.name) — traverse arrière", quantity: 1, width: max(0, drawerWidth - 2 * thickness), length: drawerHeight, thickness: thickness, material: materialName)
            ]
        }
        return carcass + drawerParts
    }

    var hardwareSchedule: [String] {
        openings.map { feature in
            let qty = feature.type == .drawer || feature.type == .slidingDoor ? "1 paire" : "à définir selon largeur et charge"
            return "\(feature.name) — \(feature.type.rawValue), \(feature.hardware), \(qty), course \(feature.travelMM.millimetresText), jeu \(feature.clearanceMM.millimetresText)"
        }
    }

    private static var projectFile: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("projet-amenagement.json")
    }

    private func persist() {
        let saved = SavedProject(vehicleName: vehicleName, useCase: useCase, seatsFolded: seatsFolded,
                                 width: width, length: length, height: height,
                                 thickness: thickness, materialName: materialName,
                                 dividerCount: dividerCount, scanFileURL: scanFileURL,
                                 scanBounds: scanBounds, scanDate: scanDate,
                                 measurementsConfirmed: measurementsConfirmed,
                                 scanMeasurements: scanMeasurements,
                                 openings: openings,
                                 vehicleLandmarks: vehicleLandmarks,
                                 scanQuality: scanQuality)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: Self.projectFile, options: .atomic)
    }
}

private struct SavedProject: Codable {
    let vehicleName: String
    let useCase: String?
    let seatsFolded: Bool
    let width, length, height, thickness: Double
    let materialName: String
    let dividerCount: Int
    let scanFileURL: URL?
    let scanBounds: ScanBounds?
    let scanDate: Date?
    let measurementsConfirmed: Bool
    let scanMeasurements: [String: [Double]]
    let openings: [OpeningFeature]?
    let vehicleLandmarks: [VehicleLandmark]?
    let scanQuality: ScanQuality?
}

enum VehicleLandmarkKind: String, CaseIterable, Codable, Identifiable {
    case seatFoldLimit = "Fin de banquette rabattue"
    case tailgateOpeningLeft = "Ouverture de coffre — gauche"
    case tailgateOpeningRight = "Ouverture de coffre — droite"
    case tailgateClearance = "Hauteur de fermeture du coffre"
    case wheelArchLeft = "Passage de roue — gauche"
    case wheelArchRight = "Passage de roue — droite"

    var id: String { rawValue }
    var requiredForFirstDesign: Bool { self != .wheelArchLeft && self != .wheelArchRight }
    var instruction: String {
        switch self {
        case .seatFoldLimit: "Pose le repère au bord arrière des dossiers rabattus, sur la ligne de plancher."
        case .tailgateOpeningLeft: "Touche le bord intérieur gauche de l’ouverture du coffre."
        case .tailgateOpeningRight: "Touche le bord intérieur droit de l’ouverture du coffre."
        case .tailgateClearance: "Touche le point le plus bas de la fermeture du hayon, là où le meuble doit passer."
        case .wheelArchLeft: "Touche le point le plus haut du passage de roue gauche."
        case .wheelArchRight: "Touche le point le plus haut du passage de roue droit."
        }
    }
}

struct VehicleLandmark: Identifiable, Codable {
    var id = UUID()
    var kind: VehicleLandmarkKind
    var x, y, z: Float
}

struct ScanQuality: Codable {
    let anchorCount: Int
    let triangleCount: Int
    let durationSeconds: Double
    let bounds: ScanBounds

    var geometryLooksUsable: Bool {
        anchorCount >= 4 && triangleCount >= 700 && bounds.widthMM >= 550 && bounds.lengthMM >= 600 && bounds.heightMM >= 200
    }

}

enum OpeningType: String, CaseIterable, Codable, Identifiable {
    case drawer = "Tiroir"
    case hingedDoor = "Porte battante"
    case liftUp = "Porte relevable"
    case slidingDoor = "Porte coulissante"
    var id: String { rawValue }
}

enum OpeningSide: String, CaseIterable, Codable, Identifiable {
    case left = "Gauche", right = "Droite", top = "Haut", bottom = "Bas", rear = "Arrière"
    var id: String { rawValue }
}

enum OpeningDirection: String, CaseIterable, Codable, Identifiable {
    case outward = "Vers l'extérieur", inward = "Vers l'intérieur", upward = "Vers le haut", downward = "Vers le bas", left = "Vers la gauche", right = "Vers la droite"
    var id: String { rawValue }
}

enum SuggestedStyle {
    case drawers, hingedDoors, mixed, openCompartments
}

struct OpeningFeature: Identifiable, Codable {
    var id = UUID()
    var name: String
    var type: OpeningType
    var side: OpeningSide
    var direction: OpeningDirection
    var widthMM: Double
    var heightMM: Double
    var travelMM: Double
    var clearanceMM: Double
    var hardware: String
    var openingAngle: Int

    static let defaultDrawer = OpeningFeature(name: "Tiroir principal", type: .drawer, side: .rear,
        direction: .outward, widthMM: 480, heightMM: 120, travelMM: 450,
        clearanceMM: 2, hardware: "Glissières télescopiques", openingAngle: 0)
}

enum MeasurementKind: String, CaseIterable, Identifiable {
    case moduleWidth, moduleLength, moduleHeight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .moduleWidth: "Largeur utile"
        case .moduleLength: "Longueur utile"
        case .moduleHeight: "Hauteur disponible"
        }
    }
    var symbol: String {
        switch self {
        case .moduleWidth: "arrow.left.and.right"
        case .moduleLength: "arrow.up.and.down"
        case .moduleHeight: "arrow.up.to.line"
        }
    }
    var instruction: String {
        switch self {
        case .moduleWidth: "Touche les bords intérieurs gauche et droit, à la même hauteur."
        case .moduleLength: "Touche le seuil arrière puis la limite avant du module."
        case .moduleHeight: "Touche le plancher puis la hauteur maximale souhaitée."
        }
    }
}

struct ScanBounds: Codable {
    let minX: Float
    let maxX: Float
    let minY: Float
    let maxY: Float
    let minZ: Float
    let maxZ: Float

    var widthMM: Double { Double(maxX - minX) * 1_000 }
    var heightMM: Double { Double(maxY - minY) * 1_000 }
    var lengthMM: Double { Double(maxZ - minZ) * 1_000 }
    var centerX: Float { (minX + maxX) / 2 }
    var rearZ: Float { maxZ }
    var floorY: Float { minY }
}

struct CutPart: Identifiable {
    let name: String
    let quantity: Int
    let width: Double
    let length: Double
    let thickness: Double
    let material: String
    var id: String { name }
}

extension Double {
    var millimetresText: String { formatted(.number.precision(.fractionLength(0))) + " mm" }
}
