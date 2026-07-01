//
//  MoonAnimationView.swift
//  MadaNeteru?
//
//  Home のヒーローカード用。Weather-night.json の見た目に寄せた
//  月＋星のアニメーション。
//

import SwiftUI

struct MoonAnimationView: View {
    private let canvasSize: CGFloat = 256
    var size: CGFloat = 92

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let frame = frameIndex(for: context.date)

            ZStack {
                ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                    StarShape()
                        .fill(Color(hex: "FFCC30"))
                        .frame(width: star.size, height: star.size)
                        .position(star.position)
                        .opacity(star.opacity(at: frame))
                }

                MoonShape()
                    .fill(Color(hex: "FFCC30"))
                    .frame(width: 180.8, height: 178.4)
                    .position(x: 128.4, y: 128.2)
            }
            .frame(width: canvasSize, height: canvasSize)
            .scaleEffect(size / canvasSize, anchor: .topLeading)
            .frame(width: size, height: size, alignment: .topLeading)
            .shadow(color: Color(hex: "FFCC30").opacity(0.18), radius: 10)
            .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
    }

    private func frameIndex(for date: Date) -> Double {
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0) / 3.0
        return progress * 179.0
    }

    private let stars: [AnimatedStar] = [
        .init(position: CGPoint(x: 202, y: 219), size: 22, keyframes: [
            .init(frame: 0, opacity: 1.0),
            .init(frame: 45, opacity: 0.0),
            .init(frame: 90, opacity: 1.0),
            .init(frame: 135, opacity: 0.0),
            .init(frame: 179, opacity: 1.0),
        ]),
        .init(position: CGPoint(x: 184.5, y: 63.5), size: 13, keyframes: [
            .init(frame: 10, opacity: 0.0),
            .init(frame: 50, opacity: 1.0),
            .init(frame: 100, opacity: 0.0),
            .init(frame: 140, opacity: 1.0),
            .init(frame: 175, opacity: 0.0),
        ]),
        .init(position: CGPoint(x: 23.5, y: 170.5), size: 17, keyframes: [
            .init(frame: 0, opacity: 0.0),
            .init(frame: 5, opacity: 1.0),
            .init(frame: 40, opacity: 0.0),
            .init(frame: 80, opacity: 1.0),
            .init(frame: 120, opacity: 0.0),
            .init(frame: 160, opacity: 1.0),
            .init(frame: 179, opacity: 0.0),
        ]),
        .init(position: CGPoint(x: 148, y: 107), size: 18, keyframes: [
            .init(frame: 0, opacity: 0.0),
            .init(frame: 15, opacity: 1.0),
            .init(frame: 55, opacity: 0.0),
            .init(frame: 95, opacity: 1.0),
            .init(frame: 135, opacity: 0.0),
            .init(frame: 169, opacity: 1.0),
            .init(frame: 179, opacity: 0.0),
        ]),
    ]
}

struct SunAnimationView: View {
    private let canvasSize: CGFloat = 512
    var size: CGFloat = 68

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let frame = frameIndex(for: context.date)
            let rotation = Angle(degrees: frame * (45.0 / 359.0))

            ZStack {
                RaysShape()
                    .stroke(Color(hex: "FBBF24"), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .frame(width: 360, height: 360)
                    .rotationEffect(rotation)

                SunCoreShape()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: "FBBF24"), location: 0.0),
                                .init(color: Color(hex: "FBBF24"), location: 0.45),
                                .init(color: Color(hex: "F7AE18"), location: 0.72),
                                .init(color: Color(hex: "F59E0B"), location: 1.0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 84
                        )
                    )
                    .overlay {
                        SunCoreShape()
                            .stroke(Color(hex: "F7AE18"), lineWidth: 6)
                    }
                    .frame(width: 168, height: 168)
            }
            .frame(width: canvasSize, height: canvasSize)
            .scaleEffect(size / canvasSize, anchor: .topLeading)
            .frame(width: size, height: size, alignment: .topLeading)
            .shadow(color: Color(hex: "FBBF24").opacity(0.20), radius: 10)
            .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
    }

    private func frameIndex(for date: Date) -> Double {
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.0) / 6.0
        return progress * 359.0
    }
}

private struct AnimatedStar {
    struct Keyframe {
        let frame: Double
        let opacity: Double
    }

    let position: CGPoint
    let size: CGFloat
    let keyframes: [Keyframe]

    func opacity(at frame: Double) -> Double {
        guard let first = keyframes.first else { return 1.0 }
        if frame <= first.frame { return first.opacity }

        for pair in zip(keyframes, keyframes.dropFirst()) {
            let start = pair.0
            let end = pair.1
            guard frame <= end.frame else { continue }
            let local = (frame - start.frame) / max(1, end.frame - start.frame)
            return start.opacity + ((end.opacity - start.opacity) * local)
        }
        return keyframes.last?.opacity ?? 1.0
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        bezierPath(
            in: rect,
            vertices: [
                CGPoint(x: 0.0, y: 0.5),
                CGPoint(x: 0.5, y: 1.0),
                CGPoint(x: 1.0, y: 0.5),
                CGPoint(x: 0.5, y: 0.0),
            ],
            inTangents: [
                CGPoint(x: -0.2395, y: 0.073),
                CGPoint(x: -0.073, y: -0.2395),
                CGPoint(x: 0.2395, y: -0.073),
                CGPoint(x: 0.073, y: 0.2395),
            ],
            outTangents: [
                CGPoint(x: 0.2395, y: 0.073),
                CGPoint(x: 0.073, y: -0.2395),
                CGPoint(x: -0.2395, y: -0.073),
                CGPoint(x: -0.073, y: 0.2395),
            ]
        )
    }
}

private struct MoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        bezierPath(
            in: rect,
            vertices: [
                CGPoint(x: 70.5 / 180.8, y: 0.0 / 178.4),
                CGPoint(x: 62.9 / 180.8, y: 33.1 / 178.4),
                CGPoint(x: 139.7 / 180.8, y: 109.6 / 178.4),
                CGPoint(x: 180.8 / 180.8, y: 97.7 / 178.4),
                CGPoint(x: 90.6 / 180.8, y: 178.4 / 178.4),
                CGPoint(x: 0.0 / 180.8, y: 88.1 / 178.4),
            ],
            inTangents: [
                CGPoint(x: -40.4 / 180.8, y: 9.1 / 178.4),
                CGPoint(x: 0.0 / 180.8, y: -11.8 / 178.4),
                CGPoint(x: -42.4 / 180.8, y: 0.0 / 178.4),
                CGPoint(x: -11.9 / 180.8, y: 7.5 / 178.4),
                CGPoint(x: 46.8 / 180.8, y: 0.0 / 178.4),
                CGPoint(x: 0.0 / 180.8, y: 49.9 / 178.4),
            ],
            outTangents: [
                CGPoint(x: -4.8 / 180.8, y: 10.0 / 178.4),
                CGPoint(x: 0.0 / 180.8, y: 42.3 / 178.4),
                CGPoint(x: 15.1 / 180.8, y: 0.0 / 178.4),
                CGPoint(x: -4.8 / 180.8, y: 45.3 / 178.4),
                CGPoint(x: -50.0 / 180.8, y: 0.0 / 178.4),
                CGPoint(x: 0.0 / 180.8, y: -43.0 / 178.4),
            ]
        )
    }
}

private struct SunCoreShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }
}

private struct RaysShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let inner: CGFloat = rect.width * 0.255
        let outer: CGFloat = rect.width * 0.352
        let diagonalsInner: CGFloat = rect.width * 0.180
        let diagonalsOuter: CGFloat = rect.width * 0.249

        path.move(to: CGPoint(x: c.x + inner, y: c.y))
        path.addLine(to: CGPoint(x: c.x + outer, y: c.y))
        path.move(to: CGPoint(x: c.x - inner, y: c.y))
        path.addLine(to: CGPoint(x: c.x - outer, y: c.y))

        path.move(to: CGPoint(x: c.x, y: c.y + inner))
        path.addLine(to: CGPoint(x: c.x, y: c.y + outer))
        path.move(to: CGPoint(x: c.x, y: c.y - inner))
        path.addLine(to: CGPoint(x: c.x, y: c.y - outer))

        path.move(to: CGPoint(x: c.x + diagonalsInner, y: c.y + diagonalsInner))
        path.addLine(to: CGPoint(x: c.x + diagonalsOuter, y: c.y + diagonalsOuter))
        path.move(to: CGPoint(x: c.x - diagonalsInner, y: c.y - diagonalsInner))
        path.addLine(to: CGPoint(x: c.x - diagonalsOuter, y: c.y - diagonalsOuter))

        path.move(to: CGPoint(x: c.x - diagonalsInner, y: c.y + diagonalsInner))
        path.addLine(to: CGPoint(x: c.x - diagonalsOuter, y: c.y + diagonalsOuter))
        path.move(to: CGPoint(x: c.x + diagonalsInner, y: c.y - diagonalsInner))
        path.addLine(to: CGPoint(x: c.x + diagonalsOuter, y: c.y - diagonalsOuter))

        return path
    }
}

private func bezierPath(
    in rect: CGRect,
    vertices: [CGPoint],
    inTangents: [CGPoint],
    outTangents: [CGPoint]
) -> Path {
    var path = Path()
    guard !vertices.isEmpty, vertices.count == inTangents.count, vertices.count == outTangents.count else {
        return path
    }

    let scaledVertices = vertices.map { point in
        CGPoint(x: rect.minX + (point.x * rect.width), y: rect.minY + (point.y * rect.height))
    }
    let scaledInTangents = inTangents.map { point in
        CGPoint(x: point.x * rect.width, y: point.y * rect.height)
    }
    let scaledOutTangents = outTangents.map { point in
        CGPoint(x: point.x * rect.width, y: point.y * rect.height)
    }

    path.move(to: scaledVertices[0])

    for index in 0..<scaledVertices.count {
        let next = (index + 1) % scaledVertices.count
        let current = scaledVertices[index]
        let target = scaledVertices[next]
        let control1 = CGPoint(x: current.x + scaledOutTangents[index].x, y: current.y + scaledOutTangents[index].y)
        let control2 = CGPoint(x: target.x + scaledInTangents[next].x, y: target.y + scaledInTangents[next].y)
        path.addCurve(to: target, control1: control1, control2: control2)
    }

    path.closeSubpath()
    return path
}
