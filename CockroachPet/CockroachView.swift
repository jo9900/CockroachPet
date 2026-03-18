import SwiftUI

/// Programmatic cockroach drawing. Replace with sprite sheets later.
struct CockroachView: View {
    @ObservedObject var cockroach: Cockroach

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let scale = cockroach.isBaby ? 0.33 : 1.0
            let bodyW: CGFloat = 30 * scale
            let bodyH: CGFloat = 18 * scale

            // Apply rotation
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: center.x, y: center.y)
            transform = transform.rotated(by: -cockroach.angle) // negate for screen coords
            if cockroach.flipProgress > 0 {
                // Flip effect: scale X
                transform = transform.scaledBy(x: 1.0 - cockroach.flipProgress * 0.3, y: 1.0)
            }
            if cockroach.isSquished {
                transform = transform.scaledBy(x: 1.3, y: cockroach.scaleY)
            }
            transform = transform.translatedBy(x: -center.x, y: -center.y)

            context.transform = transform

            let bodyColor = cockroach.isBaby
                ? Color(red: 0.72, green: 0.52, blue: 0.32)  // lighter brown
                : Color(red: 0.45, green: 0.25, blue: 0.1)   // dark brown

            let darkBrown = Color(red: 0.3, green: 0.15, blue: 0.05)

            // Body raise offset (alert state)
            let raiseOffset = cockroach.bodyRaise * 3 * scale

            // Fly height offset — body lifts up when flying
            let flyOffset = cockroach.state == .flying ? cockroach.flyHeight : 0

            // MARK: - Legs (draw behind body)
            let legColor = darkBrown
            let legLength: CGFloat = 14 * scale
            let legWidth: CGFloat = 1.5 * scale
            let legPhase = cockroach.legPhase

            // 3 legs per side: front legs forward, middle sideways, back legs backward
            let legBaseAngles: [CGFloat] = [
                .pi * 0.35,  // front legs: angled forward-outward
                .pi * 0.55,  // middle legs: slightly behind perpendicular
                .pi * 0.78   // back legs: angled backward
            ]
            let legPositions: [CGFloat] = [0.28, 0.0, -0.28]

            for side in [-1.0, 1.0] {
                for i in 0..<3 {
                    let baseX = center.x + CGFloat(legPositions[i]) * bodyW
                    let baseY = center.y + CGFloat(side) * bodyH * 0.35 - raiseOffset - flyOffset

                    let phaseOffset = CGFloat(i) * 0.7 + (side > 0 ? .pi : 0)
                    var legAngle: CGFloat

                    if cockroach.state == .dragged || cockroach.state == .flipped {
                        legAngle = CGFloat(side) * legBaseAngles[i] + sin(legPhase * 8 + phaseOffset) * 0.6
                    } else if cockroach.speed > 0 {
                        legAngle = CGFloat(side) * legBaseAngles[i] + sin(legPhase + phaseOffset) * 0.25
                    } else {
                        legAngle = CGFloat(side) * legBaseAngles[i]
                    }

                    let endX = baseX + cos(legAngle) * legLength
                    let endY = baseY + sin(legAngle) * legLength

                    let jointAngle = legAngle + CGFloat(side) * 0.3
                    let midX = baseX + cos(jointAngle) * legLength * 0.5
                    let midY = baseY + sin(jointAngle) * legLength * 0.55

                    var legPath = Path()
                    legPath.move(to: CGPoint(x: baseX, y: baseY))
                    legPath.addLine(to: CGPoint(x: midX, y: midY))
                    legPath.addLine(to: CGPoint(x: endX, y: endY))

                    context.stroke(legPath, with: .color(legColor), lineWidth: legWidth)
                }
            }

            // MARK: - Grooming animation
            if cockroach.state == .grooming {
                let groomReach = sin(cockroach.groomPhase) * 0.5 + 0.5
                let groomBaseX = center.x + 0.28 * bodyW
                let groomBaseY = center.y - bodyH * 0.35 - raiseOffset - flyOffset

                let groomTipX = groomBaseX + bodyW * 0.3 + groomReach * bodyW * 0.15
                let groomTipY = groomBaseY - legLength * 0.3 - groomReach * legLength * 0.4
                let groomMidX = groomBaseX + bodyW * 0.15
                let groomMidY = groomBaseY - legLength * 0.4

                var groomPath = Path()
                groomPath.move(to: CGPoint(x: groomBaseX, y: groomBaseY))
                groomPath.addLine(to: CGPoint(x: groomMidX, y: groomMidY))
                groomPath.addLine(to: CGPoint(x: groomTipX, y: groomTipY))
                context.stroke(groomPath, with: .color(legColor), lineWidth: legWidth * 1.2)
            }

            // MARK: - Antennae (cockroach-style: very long, wide V, graceful curve)
            let antennaLength: CGFloat = 42 * scale
            let antennaWidth: CGFloat = 0.8 * scale
            let antennaWave = sin(cockroach.antennaPhase) * 0.12

            for side in [-1.0, 1.0] {
                // Base at head tip
                let baseX = center.x + bodyW * 0.48
                let baseY = center.y + CGFloat(side) * bodyH * 0.08 - raiseOffset - flyOffset

                // Wide V spread: ~50-60° outward from forward axis
                let spreadAngle: CGFloat = CGFloat(side) * 0.95 + antennaWave

                // Two-segment curve for natural sweep
                // First segment: goes forward-outward
                let mid1X = baseX + antennaLength * 0.4
                let mid1Y = baseY + CGFloat(side) * antennaLength * 0.25

                // Tip: curves further out and slightly back (natural droop)
                let tipX = baseX + cos(spreadAngle) * antennaLength * 0.7
                let tipY = baseY + sin(spreadAngle) * antennaLength * 0.85

                // Control points for smooth S-curve
                let ctrl1X = baseX + antennaLength * 0.25
                let ctrl1Y = baseY + CGFloat(side) * antennaLength * 0.05

                let ctrl2X = baseX + antennaLength * 0.5
                let ctrl2Y = baseY + CGFloat(side) * antennaLength * 0.55

                var path = Path()
                path.move(to: CGPoint(x: baseX, y: baseY))
                path.addCurve(
                    to: CGPoint(x: tipX, y: tipY),
                    control1: CGPoint(x: ctrl1X, y: ctrl1Y),
                    control2: CGPoint(x: ctrl2X, y: ctrl2Y)
                )

                // Taper: thick at base, thin at tip
                context.stroke(path, with: .color(darkBrown), lineWidth: antennaWidth)

                // Draw thinner tip extension
                let tipExtX = tipX + cos(spreadAngle + CGFloat(side) * 0.3) * antennaLength * 0.25
                let tipExtY = tipY + sin(spreadAngle + CGFloat(side) * 0.3) * antennaLength * 0.25

                var tipPath = Path()
                tipPath.move(to: CGPoint(x: tipX, y: tipY))
                tipPath.addLine(to: CGPoint(x: tipExtX, y: tipExtY))
                context.stroke(tipPath, with: .color(darkBrown.opacity(0.6)), lineWidth: antennaWidth * 0.5)
            }

            // MARK: - Body (oval)
            let bodyRect = CGRect(
                x: center.x - bodyW / 2,
                y: center.y - bodyH / 2 - raiseOffset - flyOffset,
                width: bodyW,
                height: bodyH
            )
            let bodyPath = Path(ellipseIn: bodyRect)
            context.fill(bodyPath, with: .color(bodyColor))

            // Body segments (pronotum - head shield)
            let headShieldRect = CGRect(
                x: center.x + bodyW * 0.15,
                y: center.y - bodyH * 0.4 - raiseOffset - flyOffset,
                width: bodyW * 0.35,
                height: bodyH * 0.8
            )
            context.fill(Path(ellipseIn: headShieldRect), with: .color(darkBrown.opacity(0.5)))

            // Wing lines on body
            var wingLine = Path()
            wingLine.move(to: CGPoint(x: center.x - bodyW * 0.1, y: center.y - bodyH * 0.35 - raiseOffset - flyOffset))
            wingLine.addLine(to: CGPoint(x: center.x - bodyW * 0.35, y: center.y - raiseOffset - flyOffset))
            context.stroke(wingLine, with: .color(darkBrown.opacity(0.3)), lineWidth: 0.5 * scale)

            var wingLine2 = Path()
            wingLine2.move(to: CGPoint(x: center.x - bodyW * 0.1, y: center.y + bodyH * 0.35 - raiseOffset - flyOffset))
            wingLine2.addLine(to: CGPoint(x: center.x - bodyW * 0.35, y: center.y - raiseOffset))
            context.stroke(wingLine2, with: .color(darkBrown.opacity(0.3)), lineWidth: 0.5 * scale)

            // MARK: - Flying wings + shadow
            if cockroach.state == .flying {
                let wingBuzz = sin(cockroach.legPhase * 15) * 0.1 + 0.9
                let wingColor = Color(red: 0.55, green: 0.35, blue: 0.15).opacity(0.3)
                
                // Body center Y (same offset as the body itself)
                let bodyCenterY = center.y - raiseOffset - flyOffset
                
                // Wings spread to both sides, attached to body
                let wingW = bodyW * 0.6
                let wingH = bodyH * 1.3 * wingBuzz
                
                // Left wing (above body center in canvas = one side of cockroach)
                let leftWing = CGRect(
                    x: center.x - bodyW * 0.3,
                    y: bodyCenterY - bodyH * 0.3 - wingH,
                    width: wingW,
                    height: wingH
                )
                context.fill(Path(ellipseIn: leftWing), with: .color(wingColor))
                
                // Right wing (below body center in canvas = other side)
                let rightWing = CGRect(
                    x: center.x - bodyW * 0.3,
                    y: bodyCenterY + bodyH * 0.3,
                    width: wingW,
                    height: wingH
                )
                context.fill(Path(ellipseIn: rightWing), with: .color(wingColor))
                
                // Shadow stays on the "ground" (doesn't follow flyOffset)
                let shadowRect = CGRect(
                    x: center.x - bodyW * 0.35,
                    y: center.y + bodyH * 0.5,
                    width: bodyW * 0.7,
                    height: bodyH * 0.25
                )
                let shadowAlpha = max(0.05, 0.2 - Double(flyOffset) / 300.0)
                context.fill(Path(ellipseIn: shadowRect),
                            with: .color(Color.black.opacity(shadowAlpha)))
            }

            // MARK: - Eyes
            let eyeSize: CGFloat = 3.0 * scale
            let isNight = NightModeManager.shared.isNightMode
            for side in [-1.0, 1.0] {
                let eyeX = center.x + bodyW * 0.38
                let eyeY = center.y + CGFloat(side) * bodyH * 0.2 - raiseOffset - flyOffset

                if isNight {
                    let glowSize = eyeSize * 3
                    let glowRect = CGRect(x: eyeX - glowSize / 2, y: eyeY - glowSize / 2,
                                          width: glowSize, height: glowSize)
                    context.fill(Path(ellipseIn: glowRect),
                                with: .color(Color.red.opacity(0.3)))
                    let eyeRect = CGRect(x: eyeX - eyeSize / 2, y: eyeY - eyeSize / 2,
                                          width: eyeSize, height: eyeSize)
                    context.fill(Path(ellipseIn: eyeRect), with: .color(Color.red))
                } else {
                    let eyeRect = CGRect(x: eyeX - eyeSize / 2, y: eyeY - eyeSize / 2,
                                          width: eyeSize, height: eyeSize)
                    context.fill(Path(ellipseIn: eyeRect), with: .color(.black))
                }
            }

            // MARK: - Death X eyes
            if cockroach.state == .dying || cockroach.state == .dead {
                for side in [-1.0, 1.0] {
                    let eyeX = center.x + bodyW * 0.38
                    let eyeY = center.y + CGFloat(side) * bodyH * 0.2 - raiseOffset
                    let xSize: CGFloat = 3.0 * scale
                    var xPath = Path()
                    xPath.move(to: CGPoint(x: eyeX - xSize, y: eyeY - xSize))
                    xPath.addLine(to: CGPoint(x: eyeX + xSize, y: eyeY + xSize))
                    xPath.move(to: CGPoint(x: eyeX + xSize, y: eyeY - xSize))
                    xPath.addLine(to: CGPoint(x: eyeX - xSize, y: eyeY + xSize))
                    context.stroke(xPath, with: .color(.red), lineWidth: 1.5 * scale)
                }
            }

            // MARK: - Flipped indicator
            if cockroach.flipProgress > 0.5 {
                // Show belly - lighter color
                let bellyRect = CGRect(
                    x: center.x - bodyW * 0.35,
                    y: center.y - bodyH * 0.3 - raiseOffset - flyOffset,
                    width: bodyW * 0.7,
                    height: bodyH * 0.6
                )
                context.fill(Path(ellipseIn: bellyRect),
                            with: .color(Color(red: 0.7, green: 0.5, blue: 0.3).opacity(Double(cockroach.flipProgress))))
            }

        }
        .opacity(cockroach.opacity)
        .frame(width: cockroach.state == .flying ? cockroach.size * 6 : cockroach.size * 3, height: cockroach.state == .flying ? cockroach.size * 6 : cockroach.size * 3)
        .mask(
            // During entering, reveal from top (antennae first) downward
            VStack(spacing: 0) {
                Color.black
                    .frame(height: cockroach.state == .entering
                        ? cockroach.size * 3 * cockroach.enteringPhase
                        : (cockroach.state == .flying ? cockroach.size * 6 : cockroach.size * 3))
                Spacer(minLength: 0)
            }
        )
    }
}
