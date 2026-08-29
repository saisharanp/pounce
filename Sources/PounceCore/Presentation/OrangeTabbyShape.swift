import SwiftUI

/// A native, layered illustration whose individual parts can move with a `CatPose`.
public struct OrangeTabbyShape: View {
    public let pose: CatPose
    public let highContrast: Bool

    public init(pose: CatPose, highContrast: Bool) {
        self.pose = pose
        self.highContrast = highContrast
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 160
            let palette = TabbyPalette(highContrast: highContrast)

            ZStack {
                tail(palette: palette)
                    .offset(x: pose.bodyX, y: pose.bodyY)

                ZStack {
                    bodyLayer(palette: palette)
                    pawLayer(palette: palette)
                    headLayer(palette: palette)
                        .offset(x: pose.headX, y: pose.headY)
                        .rotationEffect(.degrees(pose.headRotation), anchor: .bottom)
                }
                .scaleEffect(x: pose.bodyScaleX, y: pose.bodyScaleY, anchor: .bottom)
                .rotationEffect(.degrees(pose.bodyRotation), anchor: .bottom)
                .offset(x: pose.bodyX, y: pose.bodyY)
            }
            .frame(width: 160, height: 160)
            .scaleEffect(scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(pose.opacity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func tail(palette: TabbyPalette) -> some View {
        ZStack {
            CatTailPath()
                .stroke(
                    palette.outline,
                    style: StrokeStyle(lineWidth: highContrast ? 20 : 18, lineCap: .round)
                )
            CatTailPath()
                .stroke(
                    palette.orange,
                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                )
            CatTailPath()
                .trim(from: 0.38, to: 0.96)
                .stroke(
                    palette.stripe,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [4, 12])
                )
        }
        .rotationEffect(.degrees(pose.tailRotation), anchor: UnitPoint(x: 0.68, y: 0.72))
    }

    private func bodyLayer(palette: TabbyPalette) -> some View {
        ZStack {
            Ellipse()
                .fill(palette.orange)
                .overlay {
                    Ellipse().stroke(palette.outline, lineWidth: highContrast ? 3.2 : 1.8)
                }
                .frame(width: 96, height: 82)
                .position(x: 78, y: 108)

            Capsule()
                .fill(palette.cream)
                .frame(width: 30, height: 55)
                .rotationEffect(.degrees(-7))
                .position(x: 65, y: 104)

            bodyStripe(width: 32, rotation: -58, x: 54, y: 88, palette: palette)
            bodyStripe(width: 36, rotation: -52, x: 47, y: 101, palette: palette)
            bodyStripe(width: 31, rotation: -43, x: 47, y: 115, palette: palette)

            Capsule()
                .fill(palette.stripe)
                .frame(width: 27, height: 6)
                .rotationEffect(.degrees(18))
                .position(x: 102, y: 92)

            rearLeg(palette: palette)
        }
    }

    private func bodyStripe(
        width: CGFloat,
        rotation: Double,
        x: CGFloat,
        y: CGFloat,
        palette: TabbyPalette
    ) -> some View {
        Capsule()
            .fill(palette.stripe)
            .frame(width: width, height: 6)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
    }

    private func rearLeg(palette: TabbyPalette) -> some View {
        ZStack(alignment: .trailing) {
            Capsule()
                .fill(palette.orange)
                .overlay {
                    Capsule().stroke(palette.outline, lineWidth: highContrast ? 3 : 1.6)
                }
            Ellipse()
                .fill(palette.cream)
                .frame(width: 19, height: 13)
                .padding(.trailing, 2)
        }
        .frame(width: 38 + CGFloat(pose.rearLegExtension * 12), height: 20)
        .rotationEffect(.degrees(7))
        .position(x: 105 + CGFloat(pose.rearLegExtension * 5), y: 136)
    }

    private func pawLayer(palette: TabbyPalette) -> some View {
        ZStack {
            frontPaw(x: 58, palette: palette)
                .offset(y: pose.frontPawY + pose.pawAlternation * 4)
                .rotationEffect(.degrees(-pose.pawAlternation * 8), anchor: .top)
            frontPaw(x: 83, palette: palette)
                .offset(y: pose.frontPawY - pose.pawAlternation * 4)
                .rotationEffect(.degrees(pose.pawAlternation * 8), anchor: .top)
        }
    }

    private func frontPaw(x: CGFloat, palette: TabbyPalette) -> some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(palette.orange)
                .overlay {
                    Capsule().stroke(palette.outline, lineWidth: highContrast ? 2.8 : 1.5)
                }
                .frame(width: 24, height: 46)
            Ellipse()
                .fill(palette.cream)
                .frame(width: 21, height: 15)
                .overlay {
                    PawToeLines().stroke(palette.stripe, lineWidth: 1.2)
                }
        }
        .position(x: x, y: 126)
    }

    private func headLayer(palette: TabbyPalette) -> some View {
        ZStack {
            ear(x: 27, mirrored: false, palette: palette)
            ear(x: 73, mirrored: true, palette: palette)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.orange)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(palette.outline, lineWidth: highContrast ? 3.2 : 1.8)
                }
                .frame(width: 78, height: 61)
                .position(x: 50, y: 52)

            foreheadStripes(palette: palette)
            face(palette: palette)
        }
        .frame(width: 100, height: 88)
        .position(x: 74, y: 56)
    }

    private func ear(x: CGFloat, mirrored: Bool, palette: TabbyPalette) -> some View {
        ZStack {
            CatEarPath()
                .fill(palette.orange)
                .overlay {
                    CatEarPath().stroke(palette.outline, lineWidth: highContrast ? 3 : 1.7)
                }
            CatEarPath()
                .inset(by: 7)
                .fill(palette.earInner)
        }
        .frame(width: 35, height: 39)
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .rotationEffect(.degrees((mirrored ? 1 : -1) * pose.earRotation), anchor: .bottom)
        .position(x: x, y: 19)
    }

    private func foreheadStripes(palette: TabbyPalette) -> some View {
        HStack(spacing: 5) {
            ForEach([-1.0, 0.0, 1.0], id: \.self) { offset in
                Capsule()
                    .fill(palette.stripe)
                    .frame(width: 5, height: offset == 0 ? 19 : 15)
                    .rotationEffect(.degrees(offset * 15))
            }
        }
        .position(x: 50, y: 31)
    }

    private func face(palette: TabbyPalette) -> some View {
        ZStack {
            eye(x: 34, palette: palette)
            eye(x: 66, palette: palette)

            HStack(spacing: -1) {
                Circle().fill(palette.cream)
                Circle().fill(palette.cream)
            }
            .frame(width: 42, height: 25)
            .scaleEffect(pose.muzzleScale)
            .position(x: 50, y: 61)

            CatNosePath()
                .fill(palette.nose)
                .frame(width: 12, height: 8)
                .position(x: 50, y: 55)

            Ellipse()
                .fill(palette.outline)
                .frame(width: 9, height: max(1.5, 2 + CGFloat(pose.mouthOpen * 9)))
                .position(x: 50, y: 69)

            WhiskerPath()
                .stroke(palette.outline, style: StrokeStyle(lineWidth: highContrast ? 1.8 : 1.2, lineCap: .round))
        }
    }

    private func eye(x: CGFloat, palette: TabbyPalette) -> some View {
        ZStack {
            Ellipse()
                .fill(palette.eye)
                .overlay {
                    Ellipse().stroke(palette.outline, lineWidth: highContrast ? 2.2 : 1.2)
                }
            Capsule()
                .fill(palette.pupil)
                .frame(width: 5, height: 11)
                .scaleEffect(pose.pupilScale)
                .offset(x: pose.pupilX * 8)
        }
        .frame(width: 19, height: 14)
        .scaleEffect(x: 1, y: max(0.06, pose.eyeScaleY))
        .position(x: x, y: 47)
    }
}

private struct TabbyPalette {
    let orange: Color
    let cream: Color
    let stripe: Color
    let outline: Color
    let earInner: Color
    let eye: Color
    let pupil: Color
    let nose: Color

    init(highContrast: Bool) {
        orange = highContrast
            ? Color(red: 1.0, green: 0.48, blue: 0.05)
            : Color(red: 0.94, green: 0.48, blue: 0.14)
        cream = highContrast
            ? Color(red: 1.0, green: 0.96, blue: 0.78)
            : Color(red: 0.99, green: 0.88, blue: 0.67)
        stripe = highContrast
            ? Color(red: 0.28, green: 0.08, blue: 0.01)
            : Color(red: 0.48, green: 0.19, blue: 0.06)
        outline = highContrast ? .black : Color(red: 0.22, green: 0.12, blue: 0.08)
        earInner = highContrast
            ? Color(red: 1.0, green: 0.65, blue: 0.64)
            : Color(red: 0.92, green: 0.58, blue: 0.54)
        eye = highContrast
            ? Color(red: 0.78, green: 1.0, blue: 0.35)
            : Color(red: 0.62, green: 0.78, blue: 0.34)
        pupil = outline
        nose = highContrast ? Color(red: 0.55, green: 0.05, blue: 0.08) : Color(red: 0.65, green: 0.30, blue: 0.28)
    }
}

private struct CatTailPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.77))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.34),
            control1: CGPoint(x: rect.width * 0.98, y: rect.height * 0.78),
            control2: CGPoint(x: rect.width * 0.96, y: rect.height * 0.37)
        )
        return path
    }
}

private struct CatEarPath: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.08)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> CatEarPath {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

private struct CatNosePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.08)
        )
        path.closeSubpath()
        return path
    }
}

private struct WhiskerPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for yFraction in [0.52, 0.66, 0.8] {
            let y = rect.height * yFraction
            path.move(to: CGPoint(x: rect.width * 0.37, y: y - 2))
            path.addLine(to: CGPoint(x: rect.width * 0.04, y: y - 5 + yFraction * 4))
            path.move(to: CGPoint(x: rect.width * 0.63, y: y - 2))
            path.addLine(to: CGPoint(x: rect.width * 0.96, y: y - 5 + yFraction * 4))
        }
        return path
    }
}

private struct PawToeLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in [rect.width * 0.38, rect.width * 0.62] {
            path.move(to: CGPoint(x: x, y: rect.height * 0.54))
            path.addLine(to: CGPoint(x: x, y: rect.height * 0.9))
        }
        return path
    }
}
