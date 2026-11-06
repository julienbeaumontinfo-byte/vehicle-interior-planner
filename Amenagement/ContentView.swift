import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

private enum AppTab: Hashable {
    case project, scan, design, preview, workshop
}

struct ContentView: View {
    @State private var project = ProjectModel()
    @State private var selectedTab: AppTab = .project

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ProjectHomeView(project: project) { selectedTab = .scan }
            }
            .tag(AppTab.project)
            .tabItem { Label("Projet", systemImage: "square.grid.2x2.fill") }

            NavigationStack { ScannerView(project: project) }
                .tag(AppTab.scan)
                .tabItem { Label("Scanner", systemImage: "sensor") }

            NavigationStack { ConfigurationView(project: project) }
                .tag(AppTab.design)
                .tabItem { Label("Concevoir", systemImage: "slider.horizontal.3") }

            NavigationStack { Model3DView(project: project) }
                .tag(AppTab.preview)
                .tabItem { Label("Vue 3D", systemImage: "cube.transparent") }

            NavigationStack { CutListView(project: project) }
                .tag(AppTab.workshop)
                .tabItem { Label("Atelier", systemImage: "list.bullet.rectangle") }
        }
        .tint(Color(red: 0.12, green: 0.42, blue: 0.38))
    }
}

private struct ProjectHomeView: View {
    @Bindable var project: ProjectModel
    let startScan: () -> Void

    private var nextStep: String {
        if project.scanFileURL == nil { return "Scanner le coffre" }
        if !project.measurementsConfirmed { return "Vérifier les dimensions" }
        return "Contrôler l'aménagement en 3D"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ATELIER MOBILE").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.teal)
                        Text("Ton projet").font(.largeTitle.weight(.bold))
                        Text("Un coffre sur mesure, étape par étape.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "car.side.fill")
                        .font(.title2).foregroundStyle(.teal)
                        .frame(width: 48, height: 48)
                        .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("AMÉNAGEMENT DE COFFRE").font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(.white.opacity(0.72))
                            Text(project.vehicleName.replacingOccurrences(of: "Nissan ", with: "")).font(.title2.weight(.bold)).foregroundStyle(.white)
                            Text("Sièges arrière rabattus").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 30)).foregroundStyle(.white)
                            .frame(width: 62, height: 62).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    }
                    Divider().overlay(.white.opacity(0.2))
                    HStack(spacing: 0) {
                        ProjectMetric(title: "Largeur", value: project.width.millimetresText)
                        Spacer()
                        ProjectMetric(title: "Longueur", value: project.length.millimetresText)
                        Spacer()
                        ProjectMetric(title: "Panneau", value: project.thickness.millimetresText)
                    }
                }
                .padding(20)
                .background(LinearGradient(colors: [Color(red: 0.10, green: 0.37, blue: 0.34), Color(red: 0.08, green: 0.27, blue: 0.29)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("PROCHAINE ÉTAPE").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                        Spacer()
                        Text(project.scanFileURL == nil ? "1 / 5" : (project.measurementsConfirmed ? "4 / 5" : "2 / 5"))
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Text(nextStep).font(.title3.weight(.bold))
                    Text(project.scanFileURL == nil
                         ? "Le scan LiDAR crée le relevé 3D de départ."
                         : project.measurementsConfirmed
                            ? "Vérifie que le meuble s'insère bien dans le véhicule."
                            : "Le scan propose des cotes. Ajuste-les avant de passer aux panneaux.")
                        .font(.subheadline).foregroundStyle(.secondary)

                    Button(action: startScan) {
                        HStack {
                            Image(systemName: project.scanFileURL == nil ? "viewfinder" : "arrow.clockwise")
                            Text(project.scanFileURL == nil ? "Démarrer le scan LiDAR" : "Refaire le scan")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline).padding(16)
                        .foregroundStyle(.white)
                        .background(Color(red: 0.12, green: 0.42, blue: 0.38), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(.background, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.07), lineWidth: 1))

                if let scanDate = project.scanDate {
                    HStack(spacing: 13) {
                        Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Maillage LiDAR enregistré").font(.subheadline.weight(.semibold))
                            Text("\(scanDate.formatted(date: .abbreviated, time: .shortened)) · repère orienté depuis le seuil")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("TON PARCOURS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    WorkflowRow(number: "01", title: "Scanner", detail: "Relever l'intérieur au LiDAR", done: project.scanFileURL != nil)
                    WorkflowRow(number: "02", title: "Mesurer", detail: "Confirmer largeur, longueur et hauteur", done: project.measurementsConfirmed)
                    WorkflowRow(number: "03", title: "Configurer", detail: "Épaisseur et compartiments", done: project.measurementsConfirmed)
                    WorkflowRow(number: "04", title: "Vérifier", detail: "Voir le meuble dans le scan 3D", done: false)
                    WorkflowRow(number: "05", title: "Fabriquer", detail: "Liste de découpe et PDF coté", done: false, isLast: true)
                }
                .padding(20)
                .background(.background, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.07), lineWidth: 1))

                Text("Les dimensions issues du maillage sont des estimations. Contrôle-les dans le véhicule avant toute découpe.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .navigationTitle("Projet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProjectMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.white)
        }
    }
}

private struct WorkflowRow: View {
    let number: String
    let title: String
    let detail: String
    let done: Bool
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(done ? Color.teal : Color(uiColor: .tertiarySystemFill)).frame(width: 30, height: 30)
                    if done {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                    } else {
                        Text(number).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    }
                }
                if !isLast { Rectangle().fill(.primary.opacity(0.08)).frame(width: 2, height: 20) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ConfigurationView: View {
    @Bindable var project: ProjectModel
    @State private var isProposing = false
    @State private var proposalMessage: String?

    var body: some View {
        Form {
            Section("Véhicule") {
                TextField("Modèle", text: $project.vehicleName)
                Toggle("Sièges arrière rabattus", isOn: $project.seatsFolded)
            }
            Section("Besoin") {
                TextField("Que doit contenir le meuble ?", text: $project.useCase, axis: .vertical)
                    .lineLimit(2...4)
                Button {
                    Task { await proposeLayout() }
                } label: {
                    if isProposing {
                        Label("Préparation de la proposition…", systemImage: "hourglass")
                    } else {
                        Label("Proposer un aménagement", systemImage: "sparkles")
                    }
                }
                .disabled(isProposing || project.useCase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let proposalMessage {
                    Label(proposalMessage, systemImage: "lightbulb")
                        .font(.footnote).foregroundStyle(.teal)
                }
                Text("L’assistant choisit une organisation à partir du besoin. Les dimensions et les découpes restent calculées par l’application, puis vérifiées par toi.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                if project.scanBounds != nil {
                    Label("Cotes proposées par le scan · modifie-les pour décrire la zone réelle du meuble.", systemImage: "sensor")
                        .font(.footnote).foregroundStyle(.teal)
                } else {
                    Label("Lance d'abord le scan LiDAR pour obtenir des dimensions de départ.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                DimensionField(title: "Largeur extérieure", value: $project.width)
                DimensionField(title: "Longueur du coffre", value: $project.length)
                DimensionField(title: "Hauteur", value: $project.height)
            } header: { Text("Dimensions du module (mm)") }

            Section("Matériau et rangements") {
                Picker("Matériau", selection: $project.materialName) {
                    Text("Contreplaqué bouleau").tag("Contreplaqué bouleau")
                    Text("Contreplaqué peuplier").tag("Contreplaqué peuplier")
                    Text("Contreplaqué pin").tag("Contreplaqué pin")
                }
                DimensionField(title: "Épaisseur", value: $project.thickness)
                Stepper("Compartiments : \(project.dividerCount + 1)", value: $project.dividerCount, in: 0...5)
            }

            Section {
                ForEach($project.openings) { $opening in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Nom de l’ouvrant", text: $opening.name).font(.headline)
                        Picker("Type", selection: $opening.type) {
                            ForEach(OpeningType.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Côté / emplacement", selection: $opening.side) {
                            ForEach(OpeningSide.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Sens", selection: $opening.direction) {
                            ForEach(OpeningDirection.allCases) { Text($0.rawValue).tag($0) }
                        }
                        DimensionField(title: "Largeur de façade", value: $opening.widthMM)
                        DimensionField(title: "Hauteur de façade", value: $opening.heightMM)
                        if opening.type == .drawer || opening.type == .slidingDoor {
                            DimensionField(title: "Course / profondeur", value: $opening.travelMM)
                            DimensionField(title: "Jeu latéral", value: $opening.clearanceMM)
                        }
                        if opening.type == .hingedDoor || opening.type == .liftUp {
                            Stepper("Angle : \(opening.openingAngle)°", value: $opening.openingAngle, in: 45...180, step: 5)
                        }
                        TextField("Quincaillerie / référence", text: $opening.hardware)
                    }
                    .padding(.vertical, 8)
                }
                .onDelete { project.openings.remove(atOffsets: $0) }
                Button {
                    project.openings.append(OpeningFeature(name: "Nouvel ouvrant", type: .hingedDoor,
                        side: .left, direction: .outward, widthMM: 300, heightMM: 200,
                        travelMM: 0, clearanceMM: 2, hardware: "Charnières à définir", openingAngle: 90))
                } label: { Label("Ajouter une porte ou un tiroir", systemImage: "plus") }
            } header: { Text("Ouvertures et quincaillerie") } footer: {
                Text("Renseigne le côté, le sens, le dégagement et les caractéristiques de la quincaillerie réelle. La détection des collisions pendant l’ouverture est une étape à intégrer ensuite.")
            }

            Section("Contrôle des mesures") {
                Toggle("J'ai vérifié les cotes dans le véhicule", isOn: $project.measurementsConfirmed)
                if !project.measurementsConfirmed {
                    Text("Les valeurs issues du scan sont des estimations et peuvent inclure des zones que le module ne doit pas occuper.")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }

            Section("Dimensions intérieures calculées") {
                LabeledContent("Largeur utile", value: project.innerWidth.millimetresText)
                LabeledContent("Hauteur de panneau", value: project.wallHeight.millimetresText)
            }
        }
        .navigationTitle("Concevoir")
    }

    @MainActor
    private func proposeLayout() async {
        isProposing = true
        defer { isProposing = false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), LocalLayoutAssistant.isAvailable {
            do {
                let intent = try await LocalLayoutAssistant.suggest(
                    need: project.useCase, vehicle: project.vehicleName,
                    seatsFolded: project.seatsFolded, widthMM: project.width,
                    lengthMM: project.length, heightMM: project.height,
                    material: project.materialName, thicknessMM: project.thickness)
                let style: SuggestedStyle = switch intent.style {
                case .drawers: .drawers
                case .hingedDoors: .hingedDoors
                case .mixed: .mixed
                case .openCompartments: .openCompartments
                }
                project.proposeWorkStorage(style: style, zoneCount: min(4, max(1, intent.zoneCount)))
                proposalMessage = intent.summary
                return
            } catch {
                proposalMessage = "L’assistant local n’a pas répondu. Une proposition guidée a été créée."
            }
        } else {
            proposalMessage = "Le modèle local n’est pas disponible sur cet appareil. Proposition guidée créée."
        }
        #else
        proposalMessage = "Le modèle local n’est pas disponible sur cet appareil. Proposition guidée créée."
        #endif
        project.proposeWorkStorage(style: .drawers, zoneCount: 2)
    }
}

private struct DimensionField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("mm", value: $value, format: .number.precision(.fractionLength(0)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text("mm").foregroundStyle(.secondary)
        }
    }
}

private struct Model3DView: View {
    @Bindable var project: ProjectModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ScenePreview(project: project)
                    .frame(minHeight: 420)
                    .background(Color(uiColor: .secondarySystemBackground))
                Label(project.scanFileURL == nil ? "Maquette seule" : "Scan + coffre", systemImage: "cube.transparent")
                    .font(.caption.weight(.semibold)).padding(10)
                    .background(.regularMaterial, in: Capsule()).padding()
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Vérifier l'implantation").font(.headline)
                Text(project.scanFileURL == nil
                     ? "Scanne le véhicule pour superposer le meuble au relevé LiDAR."
                     : "Fais glisser pour tourner autour du scan et vérifier l'encombrement du coffre.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding()
            Spacer(minLength: 0)
        }
        .navigationTitle("Vue 3D")
    }
}

private struct CutListView: View {
    @Bindable var project: ProjectModel
    @State private var pdfURL: URL?

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: project.measurementsConfirmed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title2).foregroundStyle(project.measurementsConfirmed ? .teal : .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project.measurementsConfirmed ? "Cotes vérifiées" : "Cotes à vérifier")
                            .font(.subheadline.weight(.semibold))
                        Text(project.measurementsConfirmed ? "Le PDF reprend les dimensions actuelles." : "Confirme les mesures dans Concevoir avant d'utiliser le dossier à l'atelier.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("\(project.materialName) · \(project.thickness.millimetresText)") {
                ForEach(project.cutList) { part in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(part.name).font(.headline)
                            Spacer()
                            Text("× \(part.quantity)").foregroundStyle(.secondary)
                        }
                        Text("\(part.width.millimetresText) × \(part.length.millimetresText) × \(part.thickness.millimetresText)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }

            Section("Quincaillerie") {
                ForEach(Array(project.hardwareSchedule.enumerated()), id: \.offset) { entry in
                    Label(entry.element, systemImage: "wrench.and.screwdriver")
                        .font(.subheadline)
                }
                Text("La référence et la charge admissible doivent correspondre au catalogue du fabricant. La vérification automatique des collisions est prévue pour l’étape cinématique.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("À compléter avant fabrication") {
                Label("Découpes de passages de roue", systemImage: "circle.dashed")
                Label("Jeux, tolérances et chants", systemImage: "ruler")
                Label("Fixations et pièces imprimées", systemImage: "screwdriver")
                Text("Cette première version génère des panneaux rectangulaires. Les formes complexes et fixations ne sont pas encore décrites dans le modèle.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Dossier PDF") {
                Button {
                    pdfURL = PDFExporter.create(project: project)
                } label: {
                    Label("Générer le PDF coté", systemImage: "doc.richtext")
                }
                if let pdfURL {
                    ShareLink(item: pdfURL) { Label("Partager le dossier", systemImage: "square.and.arrow.up") }
                }
            }
        }
        .navigationTitle("Atelier")
    }
}
