# Vehicle Interior Planner

An iPhone and iPad prototype for scanning a vehicle cargo area with LiDAR, reviewing the mesh, marking vehicle reference points, and preparing a parametric plywood layout.

## Current prototype

- ARKit scene reconstruction and OBJ mesh export.
- 3D scan review with manually placed vehicle landmarks.
- Preliminary scan sufficiency guidance based on mesh density, extent, and required landmarks.
- Parametric enclosure settings, opening and hardware fields, cut list, and PDF export.
- Optional on-device layout intent extraction through Apple Foundation Models where available, with a guided fallback.

The scan quality indicator is an initial heuristic. It does not certify fit or direct-to-cut accuracy. Check vehicle measurements and hardware specifications before fabrication.

## Open in Xcode

Open `Amenagement.xcodeproj`, select the `Amenagement` scheme and a compatible iPhone or iPad. LiDAR capture requires a LiDAR-equipped device. On-device language assistance requires a supported Apple Intelligence device and OS; the app keeps a guided proposal path when it is unavailable.

## Source layout

- `Amenagement/ScannerView.swift` — LiDAR capture, scan review, landmarks, and scan quality guidance.
- `Amenagement/ProjectModel.swift` — project data and parametric configuration.
- `Amenagement/LocalLayoutAssistant.swift` — optional structured local language assistance.
- `Amenagement/ScenePreview.swift` — 3D design view.
- `Amenagement/PDFExporter.swift` — workshop PDF export.
