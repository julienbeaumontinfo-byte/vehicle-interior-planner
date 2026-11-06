import SwiftUI
import SceneKit

struct ScenePreview: UIViewRepresentable {
    @Bindable var project: ProjectModel

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = buildScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = UIColor.secondarySystemBackground
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        view.scene = buildScene()
    }

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode
        let scale: CGFloat = 1.0 / 1_000.0 // mm vers m
        let w = CGFloat(max(1, project.width)) * scale
        let l = CGFloat(max(1, project.length)) * scale
        let h = CGFloat(max(1, project.height)) * scale
        let t = CGFloat(max(1, project.thickness)) * scale
        let body = UIColor.systemOrange

        if let scanURL = project.scanFileURL,
           let scanScene = try? SCNScene(url: scanURL, options: nil) {
            let scanNode = scanScene.rootNode.clone()
            scanNode.enumerateChildNodes { node, _ in
                node.geometry?.firstMaterial?.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.16)
                node.geometry?.firstMaterial?.isDoubleSided = true
                node.geometry?.firstMaterial?.fillMode = .lines
            }
            root.addChildNode(scanNode)
        }

        let bounds = project.scanBounds
        let centerX = CGFloat(bounds?.centerX ?? 0)
        let floorY = CGFloat(bounds?.floorY ?? 0)
        let rearZ = CGFloat(bounds?.rearZ ?? 0)
        let designCenterZ = rearZ - l / 2

        addBox(root, width: w, height: t, depth: l, color: body,
               position: SCNVector3(Float(centerX), Float(floorY) + Float(t / 2), Float(designCenterZ)))
        addBox(root, width: t, height: h - t, depth: l, color: body,
               position: SCNVector3(Float(centerX - w / 2 + t / 2), Float(floorY + h / 2 + t / 2), Float(designCenterZ)))
        addBox(root, width: t, height: h - t, depth: l, color: body,
               position: SCNVector3(Float(centerX + w / 2 - t / 2), Float(floorY + h / 2 + t / 2), Float(designCenterZ)))
        let innerW = max(t, w - 2 * t)
        for z in [designCenterZ - l / 2 + t / 2, designCenterZ + l / 2 - t / 2] {
            addBox(root, width: innerW, height: h - t, depth: t, color: body,
                   position: SCNVector3(Float(centerX), Float(floorY + h / 2 + t / 2), Float(z)))
        }
        for position in project.dividerPositions {
            let z = Float(designCenterZ + l / 2 - CGFloat(position) * scale)
            addBox(root, width: innerW, height: h - t, depth: t, color: UIColor.systemTeal,
                   position: SCNVector3(Float(centerX), Float(floorY + h / 2 + t / 2), z))
        }

        // Représentation fermée des façades et volumes mobiles paramétrés.
        for (index, opening) in project.openings.enumerated() {
            let openingWidth = CGFloat(max(1, opening.widthMM)) * scale
            let openingHeight = CGFloat(max(1, opening.heightMM)) * scale
            let baySpan = max(0, innerW - t) / CGFloat(max(1, project.openings.count))
            let openingCenterX = centerX - innerW / 2 + baySpan * (CGFloat(index) + 0.5)
            let faceZ = CGFloat(rearZ)
            let faceY = CGFloat(floorY) + t + openingHeight / 2
            if opening.type == .drawer {
                let depth = CGFloat(max(1, opening.travelMM)) * scale
                addBox(root, width: openingWidth, height: openingHeight, depth: t * 0.65,
                       color: UIColor.systemOrange, position: SCNVector3(Float(openingCenterX), Float(faceY), Float(faceZ) - Float(t * 0.32)))
                let drawerCenterZ = faceZ - depth / 2
                addBox(root, width: openingWidth - 2 * t, height: openingHeight - t, depth: max(t, depth - t),
                       color: UIColor.systemYellow.withAlphaComponent(0.75), position: SCNVector3(Float(openingCenterX), Float(faceY), Float(drawerCenterZ)))
                for side in [-1.0, 1.0] {
                    addBox(root, width: t * 0.18, height: t * 0.12, depth: depth,
                           color: UIColor.systemGray, position: SCNVector3(Float(openingCenterX + CGFloat(side) * (openingWidth / 2 - t * 0.35)), Float(faceY), Float(drawerCenterZ)))
                }
            } else {
                addBox(root, width: openingWidth, height: openingHeight, depth: t * 0.55,
                       color: UIColor.systemOrange, position: SCNVector3(Float(openingCenterX), Float(faceY), Float(faceZ) - Float(t * 0.28)))
            }
        }

        // Repère de sol schématique, pour aider à juger les proportions.
        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial?.diffuse.contents = UIColor.tertiarySystemFill
        let floorNode = SCNNode(geometry: floor)
        floorNode.position.y = Float(floorY)
        root.addChildNode(floorNode)

        let camera = SCNCamera()
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(Float(centerX + w * 1.7), Float(floorY + h * 1.5), Float(designCenterZ + l * 1.8))
        cameraNode.look(at: SCNVector3(Float(centerX), Float(floorY + h / 2), Float(designCenterZ)))
        root.addChildNode(cameraNode)
        scene.lightingEnvironment.intensity = 1
        return scene
    }

    private func addBox(_ root: SCNNode, width: CGFloat, height: CGFloat, depth: CGFloat, color: UIColor, position: SCNVector3) {
        let box = SCNBox(width: width, height: height, length: depth, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = color
        box.firstMaterial?.transparency = 0.88
        box.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: box)
        node.position = position
        root.addChildNode(node)
    }
}
