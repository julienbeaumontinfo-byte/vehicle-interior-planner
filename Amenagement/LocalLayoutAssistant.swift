import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
enum SuggestedStorageStyle {
    case drawers
    case hingedDoors
    case mixed
    case openCompartments
}

@available(iOS 26.0, *)
@Generable
struct SuggestedLayoutIntent {
    @Guide(description: "Type de rangement conseillé selon le besoin : drawers, hingedDoors, mixed ou openCompartments.")
    var style: SuggestedStorageStyle

    @Guide(description: "Nombre de zones de rangement, de 1 à 4.")
    var zoneCount: Int

    @Guide(description: "Résumé bref en français. Ne donne aucune cote et ne prétends pas valider la fabrication.")
    var summary: String
}

@available(iOS 26.0, *)
enum LocalLayoutAssistant {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func suggest(need: String, vehicle: String, seatsFolded: Bool,
                        widthMM: Double, lengthMM: Double, heightMM: Double,
                        material: String, thicknessMM: Double) async throws -> SuggestedLayoutIntent {
        let session = LanguageModelSession(instructions: """
        Tu aides à choisir un concept d'aménagement intérieur de véhicule.
        Interprète le besoin et choisis uniquement un style parmi drawers, hingedDoors, mixed, openCompartments.
        Les nombres de zones sont des préférences, pas des cotes. Ne calcule aucune dimension, ne choisis aucune référence de quincaillerie,
        ne garantis jamais la fabricabilité. Réponds en français avec un résumé concis.
        """)
        let prompt = """
        Besoin : \(need)
        Véhicule : \(vehicle), sièges arrière rabattus : \(seatsFolded)
        Encombrement maximum saisi : largeur \(Int(widthMM)) mm, longueur \(Int(lengthMM)) mm, hauteur \(Int(heightMM)) mm
        Matériau prévu : \(material), épaisseur \(Int(thicknessMM)) mm
        Propose un concept simple pour ce cas d'usage.
        """
        let response = try await session.respond(to: prompt, generating: SuggestedLayoutIntent.self)
        return response.content
    }
}
#endif
