// ARMOR-IOS-CONTROL - the Radar screen: the site as Studio designed it, in 2D, with the targets of the radars moving on it. The same plan as the Android app (which also has a 3D view; the 3D view
// is not ported yet). The people come from the status the app already reads; the design is read from the server and can be reloaded.
// Written without a Mac: it is built by the CI but has not been run on an iPhone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

private let groundColour = Color(red: 0.09, green: 0.25, blue: 0.30)
private let wallColour = Color(red: 0.85, green: 0.89, blue: 0.90)
private let targetColour = Color(red: 1.0, green: 0.69, blue: 0.13)
private let ignoredColour = Color(red: 0.49, green: 0.55, blue: 0.58)
private let radarColour = Color(red: 0.0, green: 0.90, blue: 1.0)

/// A colour from a `#rrggbb` text of the design, or the fallback.
private func hex(_ text: String?, _ fallback: Color) -> Color {
    guard let text, text.count == 7, text.hasPrefix("#"), let value = UInt32(text.dropFirst(), radix: 16) else { return fallback }
    return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
}

private func featureColour(_ kind: String) -> Color {
    switch kind {
    case "tree": return Color(red: 0.18, green: 0.45, blue: 0.25)
    case "road", "path", "sidewalk": return Color(red: 0.25, green: 0.28, blue: 0.30)
    case "fence": return Color(red: 0.62, green: 0.52, blue: 0.38)
    case "fountain": return Color(red: 0.25, green: 0.55, blue: 0.75)
    default: return Color(red: 0.45, green: 0.50, blue: 0.53)
    }
}

/// The corners of a rotated rectangle feature.
private func rectCorners(_ f: SiteFeature, depth: Double? = nil) -> [SitePoint] {
    let r = f.rotation * Double.pi / 180
    let c = cos(r), s = sin(r)
    let d = depth ?? f.depth
    return [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)].map { corner in
        let lx = corner.0 * f.width / 2, ly = corner.1 * d / 2
        return SitePoint(f.x + lx * c - ly * s, f.y + lx * s + ly * c)
    }
}

/// The part of the plane that holds the site: its ground, buildings and the field of every radar - not the empty space around the origin.
private func siteBounds(_ design: SiteDesign) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
    let dims = design.dimensions
    var points = design.terrain
    for building in design.buildings { points += building.points }
    for s in design.sensors {
        let apex = RadarGeometry.toMetres(s.x, s.y, dims)
        let rated = RadarGeometry.view(s.kind)
        points += RadarGeometry.sector(apex: apex, headingDeg: RadarGeometry.headingOf(s.x, s.y, s.heading, dims), halfAngleDeg: rated.half, rangeM: rated.range)
    }
    if points.isEmpty { points = [SitePoint(0, 0), SitePoint(dims.width, dims.depth)] }
    return (points.map { $0.x }.min() ?? 0, points.map { $0.x }.max() ?? 1, points.map { $0.y }.min() ?? 0, points.map { $0.y }.max() ?? 1)
}

struct RadarView: View {
    @EnvironmentObject var model: AppModel
    @State private var design: SiteDesign?
    @State private var loaded = false
    @State private var failed = false

    private func load() async {
        guard let origin = model.activeOrigin else { return }
        do { design = try await model.controller.api.site(origin); failed = false } catch { failed = true }
        loaded = true
    }

    var body: some View {
        let nodes = model.state.snapshot.nodes
        VStack(spacing: 8) {
            if !loaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                Text(model.tr("No se pudo leer el diseño del sitio.")).foregroundColor(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let design, design.hasRadar {
                let result = RadarGeometry.place(design, nodes: nodes)
                let counted = result.placed.filter { $0.counted }.count
                let online = nodes.filter { $0.online && !$0.stale }.count
                ZStack(alignment: .topLeading) {
                    SitePlan(design: design, targets: result.placed)
                    HStack(spacing: 8) {
                        chip(counted == 1 ? model.tr("1 persona") : model.trf("%s personas", counted), counted > 0 ? targetColour : Theme.muted)
                        chip(model.trf("%s/%s nodos", online, nodes.count), !nodes.isEmpty && online == nodes.count ? Theme.ok : Theme.amber)
                    }.padding(10)
                }
                .background(Color(red: 0.02, green: 0.05, blue: 0.07), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .bottom) { Text(model.tr("Arrastra y pellizca · doble toque para centrar")).font(.caption2).foregroundColor(Theme.muted).padding(8) }
                if result.missing > 0 {
                    Text(model.tr("Hay detecciones de un nodo que no está enlazado a un radar del diseño.")).font(.footnote).foregroundColor(Theme.amber)
                }
            } else {
                VStack(spacing: 8) {
                    Text(model.tr("Aún no hay un radar diseñado")).font(.headline)
                    Text(model.tr("Coloca tus radares en el Diseñador de sitio de Studio y aparecerán aquí, con las personas que detectan.")).font(.footnote).foregroundColor(Theme.muted).multilineTextAlignment(.center)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .background(Theme.background)
        .navigationTitle(model.tr("Radar"))
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel(model.tr("Recargar el diseño")) } }
        .task { await load() }
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption.weight(.bold)).foregroundColor(color).padding(.horizontal, 10).padding(.vertical, 5).background(Color.black.opacity(0.7), in: Capsule())
    }
}

/// The plan itself: ground, buildings, things on the ground, cameras, radars with their field, the people and a scale bar. It can be moved and zoomed.
private struct SitePlan: View {
    let design: SiteDesign
    let targets: [PlacedTarget]
    @State private var zoom: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var pan = CGSize.zero
    @State private var drag = CGSize.zero

    var body: some View {
        Canvas { context, size in
            let dims = design.dimensions
            let bounds = siteBounds(design)
            let scaleBase = min((size.width - 24) / max(1, CGFloat(bounds.maxX - bounds.minX)), (size.height - 24) / max(1, CGFloat(bounds.maxY - bounds.minY)))
            let scale = scaleBase * min(10, max(0.5, zoom * pinch))
            let midX = (bounds.minX + bounds.maxX) / 2, midY = (bounds.minY + bounds.maxY) / 2
            let shift = CGSize(width: pan.width + drag.width, height: pan.height + drag.height)
            func at(_ p: SitePoint) -> CGPoint { CGPoint(x: size.width / 2 + CGFloat(p.x - midX) * scale + shift.width, y: size.height / 2 - CGFloat(p.y - midY) * scale + shift.height) }
            func poly(_ points: [SitePoint]) -> Path {
                var path = Path()
                for (index, p) in points.enumerated() { if index == 0 { path.move(to: at(p)) } else { path.addLine(to: at(p)) } }
                path.closeSubpath()
                return path
            }

            // the ground and a 5 m grid
            context.fill(poly(design.terrain), with: .color(hex(design.terrainColor, groundColour).opacity(0.55)))
            var gx = (bounds.minX / 5).rounded(.up) * 5
            while gx <= bounds.maxX { var line = Path(); line.move(to: at(SitePoint(gx, bounds.minY))); line.addLine(to: at(SitePoint(gx, bounds.maxY))); context.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 1); gx += 5 }
            var gy = (bounds.minY / 5).rounded(.up) * 5
            while gy <= bounds.maxY { var line = Path(); line.move(to: at(SitePoint(bounds.minX, gy))); line.addLine(to: at(SitePoint(bounds.maxX, gy))); context.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 1); gy += 5 }
            context.stroke(poly(design.terrain), with: .color(radarColour), style: StrokeStyle(lineWidth: 2.5, dash: [14, 9]))

            // things on the ground
            for f in design.features {
                let colour = hex(f.color, featureColour(f.kind))
                let center = at(SitePoint(f.x, f.y))
                switch f.kind {
                case "tree", "fountain":
                    let radius = max(3, CGFloat(f.width / 2) * scale)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(colour.opacity(0.85)))
                case "lamp", "mast":
                    let halo = max(6, CGFloat(max(f.width, 0.3) * 1.6) * scale), body = max(3, CGFloat(max(f.width, 0.16)) * scale)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)), with: .color(Color(red: 1, green: 0.91, blue: 0.66).opacity(0.2)))
                    context.fill(Path(ellipseIn: CGRect(x: center.x - body, y: center.y - body, width: body * 2, height: body * 2)), with: .color(colour))
                case "fence":
                    context.fill(poly(rectCorners(f, depth: max(f.depth, 0.15))), with: .color(colour))
                default:
                    context.fill(poly(rectCorners(f)), with: .color(colour.opacity(["road", "path", "sidewalk"].contains(f.kind) ? 0.9 : 1)))
                }
            }
            // buildings
            for b in design.buildings {
                context.fill(poly(b.points), with: .color(Color(red: 0.09, green: 0.14, blue: 0.17)))
                context.stroke(poly(b.points), with: .color(hex(b.color, wallColour)), lineWidth: max(2.5, CGFloat(b.thickness) * scale))
                let cx = b.points.map { $0.x }.reduce(0, +) / Double(b.points.count), cy = b.points.map { $0.y }.reduce(0, +) / Double(b.points.count)
                context.draw(Text(b.name).font(.system(size: 11)).foregroundColor(Color(red: 0.72, green: 0.78, blue: 0.81)), at: at(SitePoint(cx, cy)))
            }
            // cameras
            for c in design.cameras {
                let apex = RadarGeometry.toMetres(c.x, c.y, dims)
                let heading = RadarGeometry.headingOf(c.x, c.y, c.heading, dims)
                context.fill(poly(RadarGeometry.sector(apex: apex, headingDeg: heading, halfAngleDeg: (c.fov ?? 90) / 2, rangeM: c.range ?? 12)), with: .color(targetColour.opacity(0.10)))
                let p = at(apex)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(targetColour))
            }
            // radars: their field and the body
            for (index, s) in design.sensors.enumerated() {
                let apex = RadarGeometry.toMetres(s.x, s.y, dims)
                let heading = RadarGeometry.headingOf(s.x, s.y, s.heading, dims)
                let rated = RadarGeometry.view(s.kind)
                let field = poly(RadarGeometry.sector(apex: apex, headingDeg: heading, halfAngleDeg: rated.half, rangeM: rated.range))
                context.fill(field, with: .color(radarColour.opacity(0.13)))
                context.stroke(field, with: .color(radarColour.opacity(0.55)), lineWidth: 1.5)
                for r in [2.0, 4.0] {
                    var arc = Path()
                    for (i, p) in RadarGeometry.sector(apex: apex, headingDeg: heading, halfAngleDeg: rated.half, rangeM: r).dropFirst().enumerated() { if i == 0 { arc.move(to: at(p)) } else { arc.addLine(to: at(p)) } }
                    context.stroke(arc, with: .color(radarColour.opacity(0.2)), lineWidth: 1)
                }
                let p = at(apex)
                context.fill(Path(CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(radarColour))
                // radars of one node stand in one place: the name is written once
                if !design.sensors.prefix(index).contains(where: { $0.x == s.x && $0.y == s.y }) {
                    let same = design.sensors.filter { $0.x == s.x && $0.y == s.y }
                    let label = same.count > 1 ? "\(s.name.trimmingCharacters(in: CharacterSet(charactersIn: "123 "))) ×\(same.count)" : s.name
                    context.draw(Text(label).font(.system(size: 10)).foregroundColor(Color(red: 0.55, green: 0.84, blue: 1)), at: CGPoint(x: p.x + 9, y: p.y - 12), anchor: .leading)
                }
            }
            // the people
            for t in targets {
                let p = at(t.at)
                let colour = t.counted ? targetColour : ignoredColour
                if t.counted { context.fill(Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36)), with: .color(colour.opacity(0.2))) }
                context.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(colour))
                context.stroke(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(.black.opacity(0.6)), lineWidth: 1.5)
                context.draw(Text("#\(t.trackId)").font(.system(size: 10)).foregroundColor(.white), at: CGPoint(x: p.x, y: p.y + 16))
            }
            // a scale bar
            let metres = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0].last { CGFloat($0) * scale <= size.width * 0.28 } ?? 1
            let start = CGPoint(x: 16, y: size.height - 34)
            var bar = Path()
            bar.move(to: start); bar.addLine(to: CGPoint(x: start.x + CGFloat(metres) * scale, y: start.y))
            context.stroke(bar, with: .color(Color(red: 0.55, green: 0.84, blue: 1)), lineWidth: 3)
            context.draw(Text("\(Int(metres)) m").font(.system(size: 10)).foregroundColor(Color(red: 0.55, green: 0.84, blue: 1)), at: CGPoint(x: start.x, y: start.y - 10), anchor: .leading)
        }
        .gesture(DragGesture().onChanged { drag = $0.translation }.onEnded { value in pan = CGSize(width: pan.width + value.translation.width, height: pan.height + value.translation.height); drag = .zero })
        .simultaneousGesture(MagnificationGesture().onChanged { pinch = $0 }.onEnded { value in zoom = min(10, max(0.5, zoom * value)); pinch = 1 })
        .onTapGesture(count: 2) { zoom = 1; pinch = 1; pan = .zero; drag = .zero }
    }
}
