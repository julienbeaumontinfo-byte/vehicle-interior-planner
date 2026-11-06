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
        Group {
            if project.hasActiveProject {
                TabView(selection: $selectedTab) {
                    NavigationStack { ProjectManagerView(project: project) }
                        .tag(AppTab.project)
                        .tabItem { Label("Projets", systemImage: "folder") }

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
            } else {
                NavigationStack { ProjectManagerView(project: project) }
            }
        }
        .onChange(of: project.currentProjectID) { _, _ in selectedTab = .project }
        .tint(Color(red: 0.12, green: 0.42, blue: 0.38))
    }
}

private struct ProjectManagerView: View {
    @Bindable var project: ProjectModel
    @State private var isCreating = false
    @State private var newProjectName = ""
    @State private var projectToDelete: ProjectSummary?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            if project.projects.isEmpty {
                ContentUnavailableView {
                    Label("Aucun projet", systemImage: "car.side")
                } description: {
                    Text("Crée un projet pour commencer. Chaque véhicule et son aménagement seront enregistrés séparément.")
                } actions: {
                    Button("Créer un projet") { beginCreating() }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Mes projets · \(project.projects.count)") {
                    ForEach(project.projects) { item in
                        Button {
                            project.openProject(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: project.currentProjectID == item.id ? "folder.fill" : "folder")
                                    .font(.title2).foregroundStyle(.teal)
                                    .frame(width: 42, height: 42)
                                    .background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.projectName).font(.headline).foregroundStyle(.primary)
                                    Text(item.vehicleName.isEmpty ? "Véhicule à définir" : item.vehicleName)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text("Modifié le \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                if project.currentProjectID == item.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                projectToDelete = item
                                showingDeleteConfirmation = true
                            } label: { Label("Supprimer", systemImage: "trash") }
                        }
                    }
                }
                Section {
                    Text("Les changements sont enregistrés automatiquement sur cet appareil. Utilise le bouton Enregistrer dans Concevoir pour forcer une sauvegarde.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Projets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: beginCreating) { Label("Nouveau projet", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $isCreating) {
            NavigationStack {
                Form {
                    Section("Nouveau projet") {
                        TextField("Nom du projet", text: $newProjectName)
                            .textInputAutocapitalization(.words)
                    }
                    Section {
                        Text("Le véhicule, le scan LiDAR, les repères et les choix d’aménagement seront propres à ce projet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Créer un projet")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { isCreating = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Créer") {
                            project.createProject(named: newProjectName)
                            isCreating = false
                        }
                        .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Supprimer « \(projectToDelete?.projectName ?? "ce projet") » ?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer le projet et son scan", role: .destructive) {
                if let projectToDelete { project.deleteProject(projectToDelete.id) }
                projectToDelete = nil
            }
            Button("Annuler", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("Cette action supprime le projet enregistré sur cet appareil ainsi que son maillage LiDAR associé.")
        }
    }

    private func beginCreating() {
        newProjectName = ""
        isCreating = true
    }
}

private struct ConfigurationView: View {
    @Bindable var project: ProjectModel
    @State private var isProposing = false
    @State private var proposalMessage: String?
    @State private var isShowingSavedNotice = false

    var body: some View {
        Form {
            Section("Projet") {
                TextField("Nom du projet", text: $project.projectName)
            }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    project.saveCurrentProject()
                    isShowingSavedNotice = true
                } label: {
                    Label("Enregistrer", systemImage: "square.and.arrow.down")
                }
            }
        }
        .alert("Projet enregistré", isPresented: $isShowingSavedNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Les modifications de « \(project.projectName) » sont enregistrées sur cet appareil.")
        }
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
