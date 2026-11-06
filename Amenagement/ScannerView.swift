import SwiftUI
import ARKit
import Combine
import UIKit
import simd
import SceneKit

struct ScannerView: View {
    @StateObject private var scanner: LiDARScannerBridge
    private let project: ProjectModel

    init(project: ProjectModel) {
        self.project = project
        _scanner = StateObject(wrappedValue: LiDARScannerBridge(project: project))
    }

    var body: some View {
        ZStack {
            liveScanner
                .opacity(scanner.isReviewing ? 0 : 1)
                .allowsHitTesting(!scanner.isReviewing)
            if scanner.isReviewing {
                ScanReviewView(project: project, scanner: scanner)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: scanner.isReviewing)
        .navigationTitle(scanner.isReviewing ? "Résultat du scan" : "Scan du véhicule")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { scanner.finishIfNeeded() }
    }

    private var liveScanner: some View {
        VStack(spacing: 0) {
            LiDARSceneView(scanner: scanner)
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .topLeading) {
                    Label(scanner.status, systemImage: scanner.isScanning ? "record.circle" : "viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding()
                }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("\(scanner.meshCount) zones · \(scanner.triangleCount) triangles", systemImage: "cube.transparent")
                        Text(scanner.liveCoverageMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        scanner.isScanning ? scanner.stop() : scanner.start()
                    } label: {
                        Label(scanner.isScanning ? "Terminer" : "Commencer", systemImage: scanner.isScanning ? "stop.fill" : "viewfinder")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(scanner.isScanning ? .red : .orange)
                }
                Text("Commence au centre du seuil, téléphone tenu à hauteur du plancher et orienté vers l'avant. Balaye lentement le coffre, les passages de roue et la zone des sièges.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Menu {
                        Picker("Cote à mesurer", selection: $scanner.selectedMeasurementKind) {
                            ForEach(MeasurementKind.allCases) { kind in
                                Label(kind.title, systemImage: kind.symbol).tag(kind)
                            }
                        }
                    } label: {
                        Label(scanner.selectedMeasurementKind.title, systemImage: scanner.selectedMeasurementKind.symbol)
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    Button {
                        scanner.toggleMeasurementMode()
                    } label: {
                        Label(scanner.isMeasuring ? "Annuler" : "Mesurer 2 points", systemImage: scanner.isMeasuring ? "xmark" : "ruler")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(scanner.isMeasuring ? .orange : .teal)
                    .disabled(!scanner.isScanning)
                }
                if scanner.isMeasuring {
                    Text(scanner.selectedMeasurementKind.instruction)
                        .font(.caption).foregroundStyle(.teal)
                }
                if let measurementStatus = scanner.measurementStatus {
                    Label(measurementStatus, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(.teal)
                }
                if let message = scanner.message {
                    Text(message).font(.footnote).foregroundStyle(.orange)
                }
                if let scanURL = scanner.scanURL {
                    ShareLink(item: scanURL) {
                        Label("Exporter le maillage OBJ", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.background)
        }
    }
}

private struct ScanReviewView: View {
    @Bindable var project: ProjectModel
    @ObservedObject var scanner: LiDARScannerBridge
    @State private var selectedLandmark: VehicleLandmarkKind = .seatFoldLimit

    private var requiredLandmarks: [VehicleLandmarkKind] {
        VehicleLandmarkKind.allCases.filter(\.requiredForFirstDesign)
    }
    private var missingLandmarks: [VehicleLandmarkKind] {
        requiredLandmarks.filter { !project.hasLandmark($0) }
    }
    private var geometryReady: Bool { project.scanQuality?.geometryLooksUsable ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScanQualityCard(project: project, geometryReady: geometryReady, missingLandmarks: missingLandmarks)

                ScanMeshReviewView(url: project.scanFileURL, bounds: project.scanBounds,
                                   landmarks: project.vehicleLandmarks) { point in
                    project.placeLandmark(selectedLandmark, at: point)
                }
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(alignment: .topLeading) {
                    Label("Pince et fais glisser pour examiner · touche le maillage pour placer le repère", systemImage: "hand.draw")
                        .font(.caption.weight(.medium)).padding(9)
                        .background(.regularMaterial, in: Capsule()).padding(10)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Repères du véhicule").font(.headline)
                    Picker("Repère à placer", selection: $selectedLandmark) {
                        ForEach(VehicleLandmarkKind.allCases) { kind in
                            Text("\(project.hasLandmark(kind) ? "✓ " : "")\(kind.rawValue)").tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(selectedLandmark.instruction)
                        .font(.footnote).foregroundStyle(.secondary)
                    if project.hasLandmark(selectedLandmark) {
                        Button(role: .destructive) {
                            project.removeLandmark(selectedLandmark)
                        } label: { Label("Supprimer ce repère", systemImage: "trash") }
                            .font(.footnote)
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 10) {
                    Button {
                        scanner.resumeScan()
                    } label: {
                        Label("Compléter le scan", systemImage: "viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        scanner.start()
                    } label: {
                        Label("Recommencer", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if !missingLandmarks.isEmpty {
                    Text("Pour le premier aménagement, place les repères obligatoires ci-dessus. Les passages de roue sont facultatifs, mais recommandés.")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if let scanURL = project.scanFileURL {
                    ShareLink(item: scanURL) { Label("Exporter le maillage OBJ", systemImage: "square.and.arrow.up") }
                        .font(.footnote)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

private struct ScanQualityCard: View {
    let project: ProjectModel
    let geometryReady: Bool
    let missingLandmarks: [VehicleLandmarkKind]

    private var ready: Bool { geometryReady && missingLandmarks.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(ready ? "Scan exploitable · repères complets" : (geometryReady ? "Maillage capturé · repères à compléter" : "Scan à compléter"),
                  systemImage: ready ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(ready ? .teal : .orange)
            if let quality = project.scanQuality {
                Text("\(quality.anchorCount) zones de maillage · \(quality.triangleCount) triangles · \(Int(quality.durationSeconds)) s")
                    .font(.caption).foregroundStyle(.secondary)
            }
            qualityRow("Maillage assez dense et volume visible", isDone: geometryReady)
            ForEach(VehicleLandmarkKind.allCases.filter(\.requiredForFirstDesign)) { kind in
                qualityRow(kind.rawValue, isDone: project.hasLandmark(kind))
            }
            Text("Contrôle indicatif fondé sur la densité du maillage et les repères posés. Vérifie les cotes dans le véhicule avant découpe.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private func qualityRow(_ title: String, isDone: Bool) -> some View {
        Label(title, systemImage: isDone ? "checkmark.circle.fill" : "circle")
            .font(.footnote).foregroundStyle(isDone ? .primary : .secondary)
    }
}

private struct LiDARSceneView: UIViewRepresentable {
    @ObservedObject var scanner: LiDARScannerBridge

    func makeCoordinator() -> Coordinator { Coordinator(scanner: scanner) }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.delegate = context.coordinator
        context.coordinator.sceneView = view
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = true
        scanner.attach(view)
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        scanner.attach(view)
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        private let scanner: LiDARScannerBridge
        weak var sceneView: ARSCNView?

        init(scanner: LiDARScannerBridge) { self.scanner = scanner }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView, gesture.state == .ended else { return }
            scanner.measurePoint(at: gesture.location(in: sceneView), in: sceneView)
        }

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let mesh = anchor as? ARMeshAnchor else { return }
            node.geometry = Self.geometry(from: mesh)
            DispatchQueue.main.async { self.scanner.update(mesh) }
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let mesh = anchor as? ARMeshAnchor else { return }
            node.geometry = Self.geometry(from: mesh)
            DispatchQueue.main.async { self.scanner.update(mesh) }
        }

        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            guard let mesh = anchor as? ARMeshAnchor else { return }
            DispatchQueue.main.async { self.scanner.remove(mesh) }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let arView = renderer as? ARSCNView,
                  let transform = arView.session.currentFrame?.camera.transform else { return }
            scanner.captureReferenceTransform(transform)
        }

        private static func geometry(from anchor: ARMeshAnchor) -> SCNGeometry {
            let mesh = anchor.geometry
            let vertices = mesh.vertices
            let vertexSource = SCNGeometrySource(buffer: vertices.buffer,
                                                 vertexFormat: .float3,
                                                 semantic: .vertex,
                                                 vertexCount: vertices.count,
                                                 dataOffset: vertices.offset,
                                                 dataStride: vertices.stride)
            let normals = mesh.normals
            let normalSource = SCNGeometrySource(buffer: normals.buffer,
                                                 vertexFormat: .float3,
                                                 semantic: .normal,
                                                 vertexCount: normals.count,
                                                 dataOffset: normals.offset,
                                                 dataStride: normals.stride)
            let faces = mesh.faces
            let byteCount = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            let faceData = Data(bytes: faces.buffer.contents(), count: byteCount)
            let element = SCNGeometryElement(data: faceData,
                                             primitiveType: .triangles,
                                             primitiveCount: faces.count,
                                             bytesPerIndex: faces.bytesPerIndex)
            let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
            geometry.firstMaterial?.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.42)
            geometry.firstMaterial?.isDoubleSided = true
            geometry.firstMaterial?.fillMode = .lines
            return geometry
        }
    }
}

final class LiDARScannerBridge: ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var meshCount = 0
    @Published private(set) var triangleCount = 0
    @Published private(set) var status = "Prêt à scanner"
    @Published private(set) var message: String?
    @Published private(set) var scanURL: URL?
    @Published private(set) var isMeasuring = false
    @Published var selectedMeasurementKind: MeasurementKind = .moduleWidth
    @Published private(set) var measurementStatus: String?

    var isReviewing: Bool { !isScanning && scanURL != nil }
    var liveCoverageMessage: String {
        if meshCount < 4 || triangleCount < 700 { return "Balaye le plancher, les deux côtés et la zone des sièges." }
        return "Maillage suffisant en densité provisoire · les repères véhicule restent à placer."
    }

    private let project: ProjectModel
    private let referenceLock = NSLock()
    private weak var sceneView: ARSCNView?
    private var anchors: [UUID: ARMeshAnchor] = [:]
    private var referenceTransform: simd_float4x4?
    private var measurementPoints: [SIMD3<Float>] = []
    private var scanStartedAt: Date?
    private var durationBeforeSupplement: Double = 0

    init(project: ProjectModel) {
        self.project = project
        scanURL = project.scanFileURL
        meshCount = project.scanQuality?.anchorCount ?? 0
        triangleCount = project.scanQuality?.triangleCount ?? 0
        status = project.scanFileURL == nil ? "Prêt à scanner" : "Scan enregistré"
    }

    func attach(_ view: ARSCNView) { sceneView = view }

    func start() {
        beginScan(reset: true)
    }

    func resumeScan() {
        beginScan(reset: false)
    }

    private func beginScan(reset: Bool) {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
            status = "LiDAR non disponible"
            message = "Le scan nécessite un iPhone ou iPad compatible LiDAR."
            return
        }
        guard let sceneView else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.planeDetection = [.horizontal]
        if reset {
            anchors.removeAll()
            measurementPoints.removeAll()
            measurementStatus = nil
            isMeasuring = false
            referenceLock.lock()
            referenceTransform = nil
            referenceLock.unlock()
            meshCount = 0
            triangleCount = 0
            scanURL = nil
            durationBeforeSupplement = 0
            project.vehicleLandmarks = []
        } else {
            durationBeforeSupplement = project.scanQuality?.durationSeconds ?? 0
        }
        scanStartedAt = .now
        message = ""
        status = "Scan en cours"
        isScanning = true
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        sceneView.session.run(configuration, options: options)
    }

    func stop() {
        sceneView?.session.pause()
        isScanning = false
        isMeasuring = false
        measurementPoints.removeAll()
        status = "Scan terminé"
        guard !anchors.isEmpty else {
            message = "Aucun maillage reçu. Déplace l'appareil lentement dans l'habitacle et réessaie."
            return
        }
        referenceLock.lock()
        let capturedReference = referenceTransform
        referenceLock.unlock()
        guard let capturedReference,
              let result = MeshOBJExporter.export(Array(anchors.values), referenceTransform: capturedReference) else {
            message = "Impossible d'enregistrer le maillage."
            return
        }
        scanURL = result.url
        let duration = durationBeforeSupplement + (scanStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0)
        let triangles = anchors.values.reduce(0) { $0 + $1.geometry.faces.count }
        let quality = ScanQuality(anchorCount: anchors.count, triangleCount: triangles,
                                  durationSeconds: duration, bounds: result.bounds)
        triangleCount = triangles
        project.applyScan(fileURL: result.url, bounds: result.bounds, quality: quality)
        message = "Maillage enregistré. Contrôle sa couverture et place les repères dans la revue 3D."
    }

    func finishIfNeeded() {
        if isScanning { stop() }
    }

    func toggleMeasurementMode() {
        guard isScanning else { return }
        isMeasuring.toggle()
        measurementPoints.removeAll()
        measurementStatus = isMeasuring ? "Touchez le premier point, puis le second." : nil
    }

    func measurePoint(at screenPoint: CGPoint, in view: ARSCNView) {
        guard isMeasuring, isScanning,
              let query = view.raycastQuery(from: screenPoint, allowing: .estimatedPlane, alignment: .any),
              let result = view.session.raycast(query).first else { return }
        let column = result.worldTransform.columns.3
        let point = SIMD3<Float>(column.x, column.y, column.z)
        measurementPoints.append(point)
        addMarker(at: point, color: measurementPoints.count == 1 ? .systemYellow : .systemGreen, to: view)

        guard measurementPoints.count == 2 else {
            measurementStatus = "Premier point placé. Touche le second."
            return
        }

        let first = measurementPoints[0]
        let second = measurementPoints[1]
        let distanceMM = Double(simd_distance(first, second)) * 1_000
        addMeasureLine(from: first, to: second, in: view)
        project.recordMeasurement(distanceMM, for: selectedMeasurementKind)
        if let summary = project.measurementSummary(for: selectedMeasurementKind) {
            measurementStatus = "\(selectedMeasurementKind.title) : médiane \(summary.median.millimetresText) · \(summary.count) prises · plage \(summary.spread.formatted(.number.precision(.fractionLength(0)))) mm"
        }
        measurementPoints.removeAll()
    }

    private func addMarker(at point: SIMD3<Float>, color: UIColor, to view: ARSCNView) {
        let sphere = SCNSphere(radius: 0.012)
        sphere.firstMaterial?.diffuse.contents = color
        let node = SCNNode(geometry: sphere)
        node.simdPosition = point
        node.name = "cote-marqueur"
        view.scene.rootNode.addChildNode(node)
    }

    private func addMeasureLine(from start: SIMD3<Float>, to end: SIMD3<Float>, in view: ARSCNView) {
        let distance = simd_distance(start, end)
        guard distance > 0.001 else { return }
        let cylinder = SCNCylinder(radius: 0.0035, height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = UIColor.systemGreen
        let node = SCNNode(geometry: cylinder)
        node.simdPosition = (start + end) / 2
        node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(end - start))
        node.name = "cote-ligne"
        view.scene.rootNode.addChildNode(node)
    }

    func captureReferenceTransform(_ cameraTransform: simd_float4x4) {
        referenceLock.lock()
        defer { referenceLock.unlock() }
        guard referenceTransform == nil else { return }
        let cameraBack = SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
        guard simd_length(cameraBack) > 0.01 else { return }
        let back = simd_normalize(cameraBack)
        let up = SIMD3<Float>(0, 1, 0)
        let right = simd_normalize(simd_cross(up, back))
        let position = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        referenceTransform = simd_float4x4(columns: (
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(back.x, back.y, back.z, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        ))
    }

    func update(_ anchor: ARMeshAnchor) {
        anchors[anchor.identifier] = anchor
        meshCount = anchors.count
        triangleCount = anchors.values.reduce(0) { $0 + $1.geometry.faces.count }
    }

    func remove(_ anchor: ARMeshAnchor) {
        anchors.removeValue(forKey: anchor.identifier)
        meshCount = anchors.count
        triangleCount = anchors.values.reduce(0) { $0 + $1.geometry.faces.count }
    }
}

private struct ScanMeshReviewView: UIViewRepresentable {
    let url: URL?
    let bounds: ScanBounds?
    let landmarks: [VehicleLandmark]
    let onPlace: (SIMD3<Float>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPlace: onPlace) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = UIColor.secondarySystemBackground
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        context.coordinator.sceneView = view
        context.coordinator.update(url: url, bounds: bounds, landmarks: landmarks)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onPlace = onPlace
        context.coordinator.update(url: url, bounds: bounds, landmarks: landmarks)
    }

    final class Coordinator: NSObject {
        weak var sceneView: SCNView?
        var onPlace: (SIMD3<Float>) -> Void
        private var loadedURL: URL?
        private var loadedLandmarks: [VehicleLandmark] = []

        init(onPlace: @escaping (SIMD3<Float>) -> Void) { self.onPlace = onPlace }

        func update(url: URL?, bounds: ScanBounds?, landmarks: [VehicleLandmark]) {
            guard let sceneView else { return }
            if loadedURL != url {
                loadedURL = url
                if let url, let scan = try? SCNScene(url: url, options: nil) {
                    sceneView.scene = scan
                } else {
                    sceneView.scene = SCNScene()
                }
                sceneView.scene?.background.contents = UIColor.secondarySystemBackground
                addReviewCamera(bounds: bounds, to: sceneView.scene)
                loadedLandmarks = []
            }
            guard landmarks.map(\.id) != loadedLandmarks.map(\.id) else { return }
            addLandmarks(landmarks, to: sceneView.scene)
            loadedLandmarks = landmarks
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView, gesture.state == .ended else { return }
            let hits = sceneView.hitTest(gesture.location(in: sceneView), options: nil)
            guard let hit = hits.first(where: { !$0.node.name.orEmpty.hasPrefix("vehicle-landmark") }) else { return }
            let p = hit.worldCoordinates
            onPlace(SIMD3<Float>(p.x, p.y, p.z))
        }

        private func addReviewCamera(bounds: ScanBounds?, to scene: SCNScene?) {
            guard let scene else { return }
            let center = SCNVector3(bounds?.centerX ?? 0,
                                    ((bounds?.minY ?? -0.4) + (bounds?.maxY ?? 0.5)) / 2,
                                    ((bounds?.minZ ?? -1) + (bounds?.maxZ ?? 1)) / 2)
            let largestMM = max(max(bounds?.widthMM ?? 900, bounds?.lengthMM ?? 1_500), bounds?.heightMM ?? 900)
            let distance = max(Float(1.4), Float(largestMM / 1_000) * 1.45)
            let camera = SCNCamera()
            camera.zNear = 0.01
            camera.zFar = 100
            let node = SCNNode()
            node.name = "scan-review-camera"
            node.camera = camera
            node.position = SCNVector3(center.x + distance * 0.9, center.y + distance * 0.65, center.z + distance)
            node.look(at: center)
            scene.rootNode.addChildNode(node)
        }

        private func addLandmarks(_ landmarks: [VehicleLandmark], to scene: SCNScene?) {
            guard let root = scene?.rootNode else { return }
            var oldNodes: [SCNNode] = []
            root.enumerateChildNodes { node, _ in
                if node.name.orEmpty.hasPrefix("vehicle-landmark") { oldNodes.append(node) }
            }
            oldNodes.forEach { $0.removeFromParentNode() }

            for landmark in landmarks {
                let color = markerColor(landmark.kind)
                let sphere = SCNSphere(radius: 0.022)
                sphere.firstMaterial?.diffuse.contents = color
                sphere.firstMaterial?.emission.contents = color
                let marker = SCNNode(geometry: sphere)
                marker.name = "vehicle-landmark-\(landmark.kind.id)"
                marker.position = SCNVector3(landmark.x, landmark.y, landmark.z)

                let text = SCNText(string: landmark.kind.rawValue, extrusionDepth: 0.001)
                text.font = UIFont.systemFont(ofSize: 8, weight: .bold)
                text.flatness = 0.2
                text.firstMaterial?.diffuse.contents = color
                let label = SCNNode(geometry: text)
                label.name = "vehicle-landmark-label"
                label.scale = SCNVector3(0.004, 0.004, 0.004)
                label.position = SCNVector3(0.025, 0.025, 0)
                label.constraints = [SCNBillboardConstraint()]
                marker.addChildNode(label)
                root.addChildNode(marker)
            }
        }

        private func markerColor(_ kind: VehicleLandmarkKind) -> UIColor {
            switch kind {
            case .seatFoldLimit: .systemOrange
            case .tailgateOpeningLeft, .tailgateOpeningRight: .systemBlue
            case .tailgateClearance: .systemPink
            case .wheelArchLeft, .wheelArchRight: .systemPurple
            }
        }
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

private enum MeshOBJExporter {
    static func export(_ anchors: [ARMeshAnchor], referenceTransform: simd_float4x4) -> (url: URL, bounds: ScanBounds)? {
        var lines = ["# Maillage LiDAR ARKit — unités en mètres"]
        var vertexOffset: Int32 = 1
        let worldToReference = simd_inverse(referenceTransform)
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude

        for anchor in anchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices
            for index in 0..<vertices.count {
                let pointer = vertices.buffer.contents()
                    .advanced(by: vertices.offset + index * vertices.stride)
                    .assumingMemoryBound(to: SIMD3<Float>.self)
                let local = pointer.pointee
                let world = anchor.transform * SIMD4<Float>(local.x, local.y, local.z, 1)
                let point = worldToReference * world
                minX = min(minX, point.x); maxX = max(maxX, point.x)
                minY = min(minY, point.y); maxY = max(maxY, point.y)
                minZ = min(minZ, point.z); maxZ = max(maxZ, point.z)
                lines.append("v \(point.x) \(point.y) \(point.z)")
            }

            let faces = geometry.faces
            let indexPointer = faces.buffer.contents()
            for face in 0..<faces.count {
                var indices: [Int32] = []
                for corner in 0..<faces.indexCountPerPrimitive {
                    let offset = (face * faces.indexCountPerPrimitive + corner) * faces.bytesPerIndex
                    let index: UInt32
                    if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
                        index = UInt32(indexPointer.advanced(by: offset).assumingMemoryBound(to: UInt16.self).pointee)
                    } else {
                        index = indexPointer.advanced(by: offset).assumingMemoryBound(to: UInt32.self).pointee
                    }
                    indices.append(Int32(index) + vertexOffset)
                }
                lines.append("f \(indices.map { String($0) }.joined(separator: " "))")
            }
            vertexOffset += Int32(vertices.count)
        }

        guard minX.isFinite, minY.isFinite, minZ.isFinite else { return nil }
        let bounds = ScanBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY, minZ: minZ, maxZ: maxZ)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("Scans", isDirectory: true)
        let url = folder.appendingPathComponent("scan-vehicule-\(UUID().uuidString.prefix(8)).obj")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            return (url, bounds)
        } catch { return nil }
    }
}
