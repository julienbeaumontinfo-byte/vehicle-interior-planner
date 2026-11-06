import Foundation
import UIKit

enum PDFExporter {
    static func create(project: ProjectModel) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter points
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            context.beginPage()
            drawOverview(project: project, in: page)

            context.beginPage()
            drawHardware(project: project)

            for part in project.cutList {
                context.beginPage()
                drawPart(part, project: project, in: page)
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("decoupe-amenagement-\(UUID().uuidString.prefix(8)).pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func drawHardware(project: ProjectModel) {
        text("Quincaillerie et ouvertures", at: CGPoint(x: 48, y: 54), size: 22, bold: true)
        var y: CGFloat = 100
        for item in project.hardwareSchedule {
            (item as NSString).draw(in: CGRect(x: 48, y: y, width: 510, height: 48),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.black])
            drawRule(y: y + 48, x1: 48, x2: 564, color: .lightGray)
            y += 62
        }
        text("Cotes de façade et course des éléments mobiles : voir le modèle paramétrique et les pages de pièces. Confirmer les références, jeux recommandés, charge et fixations avec le fabricant de la quincaillerie avant fabrication.",
             at: CGPoint(x: 48, y: min(y + 18, 680)), size: 10)
    }

    private static func drawOverview(project: ProjectModel, in page: CGRect) {
        let margin: CGFloat = 48
        text("Dossier de découpe", at: CGPoint(x: margin, y: 52), size: 24, bold: true)
        text(project.vehicleName, at: CGPoint(x: margin, y: 88), size: 14, bold: false)
        text("Sièges arrière : \(project.seatsFolded ? "rabattus" : "relevés")", at: CGPoint(x: margin, y: 110), size: 12)
        text("Coffre : \(project.width.millimetresText) × \(project.length.millimetresText) × \(project.height.millimetresText)", at: CGPoint(x: margin, y: 142), size: 13)
        text("\(project.materialName) : \(project.thickness.millimetresText)", at: CGPoint(x: margin, y: 164), size: 13)
        text("Liste de découpe", at: CGPoint(x: margin, y: 212), size: 17, bold: true)

        let headers = ["Pièce", "Qté", "Largeur", "Longueur", "Épaisseur"]
        let columns: [CGFloat] = [margin, 235, 285, 365, 460]
        drawRule(y: 238, x1: margin, x2: page.width - margin)
        for (index, header) in headers.enumerated() {
            text(header, at: CGPoint(x: columns[index], y: 222), size: 10, bold: true)
        }
        var y: CGFloat = 258
        for part in project.cutList {
            let values = [part.name, "\(part.quantity)", part.width.millimetresText, part.length.millimetresText, part.thickness.millimetresText]
            for (index, value) in values.enumerated() {
                text(value, at: CGPoint(x: columns[index], y: y), size: 10)
            }
            drawRule(y: y + 17, x1: margin, x2: page.width - margin, color: .lightGray)
            y += 34
        }

        let note = project.measurementsConfirmed
            ? "Cotes déclarées vérifiées par l'utilisateur. Jeux, obstacles, fixations et tolérances de fabrication restent à contrôler."
            : "Dimensions estimées depuis le scan et les paramètres saisis. Mesures véhicule, jeux, obstacles, fixations et tolérances à vérifier avant découpe."
        (note as NSString).draw(in: CGRect(x: margin, y: page.height - 100, width: page.width - 2 * margin, height: 42),
                                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])
    }

    private static func drawPart(_ part: CutPart, project: ProjectModel, in page: CGRect) {
        let margin: CGFloat = 48
        text(part.name, at: CGPoint(x: margin, y: 54), size: 24, bold: true)
        text("Quantité : \(part.quantity)    Matériau : \(part.material)", at: CGPoint(x: margin, y: 88), size: 13)
        text("Cote finie : \(part.width.millimetresText) × \(part.length.millimetresText) × \(part.thickness.millimetresText)", at: CGPoint(x: margin, y: 112), size: 13, bold: true)

        let available = CGRect(x: 120, y: 245, width: page.width - 240, height: 310)
        let w = CGFloat(max(part.width, 1))
        let h = CGFloat(max(part.length, 1))
        let scale = min(available.width / w, available.height / h)
        let rect = CGRect(x: available.midX - w * scale / 2,
                          y: available.midY - h * scale / 2,
                          width: w * scale,
                          height: h * scale)
        let path = UIBezierPath(rect: rect)
        path.lineWidth = 1.5
        UIColor.systemOrange.withAlphaComponent(0.12).setFill()
        path.fill()
        UIColor.black.setStroke()
        path.stroke()

        text("\(part.width.millimetresText)", at: CGPoint(x: rect.midX - 25, y: rect.maxY + 24), size: 12, bold: true)
        let lengthLabel = "\(part.length.millimetresText)" as NSString
        lengthLabel.draw(at: CGPoint(x: rect.maxX + 12, y: rect.midY - 5),
                         withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: UIColor.black])
        text("Schéma de panneau — sans encoches ni perçages", at: CGPoint(x: margin, y: 610), size: 11)
        text("Projet : \(project.vehicleName)", at: CGPoint(x: margin, y: page.height - 60), size: 10)
    }

    private static func text(_ value: String, at point: CGPoint, size: CGFloat, bold: Bool = false) {
        let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
        (value as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: UIColor.black])
    }

    private static func drawRule(y: CGFloat, x1: CGFloat, x2: CGFloat, color: UIColor = .black) {
        color.setStroke()
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: x1, y: y))
        rule.addLine(to: CGPoint(x: x2, y: y))
        rule.lineWidth = 0.5
        rule.stroke()
    }
}
