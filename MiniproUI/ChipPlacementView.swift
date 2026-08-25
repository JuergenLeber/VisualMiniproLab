//
//  ChipPlacementView.swift
//  Visual Minipro
//

import SwiftUI

/// Draws the ZIF socket with the chip in the position it has to be inserted:
/// at the bottom of the socket, away from the lever, notch pointing up.
struct ChipPlacementView: View {
    let placement: ChipPlacement

    private let socketAspectRatio: CGFloat = 0.42

    var body: some View {
        Canvas { context, size in
            draw(in: context, size: size)
        }
        .aspectRatio(socketAspectRatio, contentMode: .fit)
        .accessibilityLabel(
            "DIP\(placement.pinCount) chip at the bottom of the socket, notch pointing up, "
                + "chip pin 1 in socket pin \(placement.firstSocketPin)"
        )
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let socketWidth = size.width
        let socketRect = CGRect(x: 0, y: 0, width: socketWidth, height: size.height)
        let rowHeight = socketRect.height / CGFloat(placement.socketRows + 2)
        let contactWidth = socketRect.width * 0.3
        let contactHeight = rowHeight * 0.55
        let leftContactX = socketRect.minX + socketRect.width * 0.09
        let rightContactX = socketRect.maxX - socketRect.width * 0.09 - contactWidth
        let firstRowY = socketRect.minY + rowHeight * 1.2

        context.fill(
            Path(roundedRect: socketRect, cornerRadius: rowHeight * 0.6),
            with: .color(.secondary.opacity(0.18))
        )

        // Lever, in the corner Xgpro draws it in.
        let leverWidth = socketRect.width * 0.07
        let lever = CGRect(
            x: socketRect.minX + socketRect.width * 0.16,
            y: socketRect.minY - rowHeight * 0.5,
            width: leverWidth,
            height: rowHeight * 1.4
        )
        context.fill(
            Path(roundedRect: lever, cornerRadius: leverWidth / 2),
            with: .color(.secondary.opacity(0.55))
        )

        for row in 0..<placement.socketRows {
            let y = firstRowY + CGFloat(row) * rowHeight
            for x in [leftContactX, rightContactX] {
                let contact = CGRect(x: x, y: y, width: contactWidth, height: contactHeight)
                context.fill(
                    Path(roundedRect: contact, cornerRadius: contactHeight * 0.35),
                    with: .color(.secondary.opacity(0.55))
                )
            }
        }

        // The chip sits on the bottom rows, spanning both contact columns.
        let chipHeight = CGFloat(placement.chipRows) * rowHeight
        let chipTopY = firstRowY + CGFloat(placement.socketRows - placement.chipRows) * rowHeight
        let chipRect = CGRect(
            x: leftContactX + contactWidth * 0.35,
            y: chipTopY - rowHeight * 0.2,
            width: rightContactX + contactWidth * 0.65 - leftContactX - contactWidth * 0.35,
            height: chipHeight
        )
        context.fill(
            Path(roundedRect: chipRect, cornerRadius: rowHeight * 0.3),
            with: .color(.accentColor.opacity(0.8))
        )

        // Pin 1 marker: the notch at the top and a dot over pin 1 itself.
        let notchRadius = chipRect.width * 0.12
        let notch = Path(
            ellipseIn: CGRect(
                x: chipRect.midX - notchRadius,
                y: chipRect.minY - notchRadius,
                width: notchRadius * 2,
                height: notchRadius * 2
            )
        )
        context.fill(notch, with: .color(.secondary.opacity(0.18)))

        let dotRadius = notchRadius * 0.45
        let dot = Path(
            ellipseIn: CGRect(
                x: chipRect.minX + notchRadius * 0.5,
                y: chipRect.minY + notchRadius * 0.5,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
        )
        context.fill(dot, with: .color(.white.opacity(0.9)))

        // Label the chip's pin 1, which is not socket pin 1 for anything
        // smaller than a full size chip.
        let pinOneLabel = context.resolve(
            Text("1").font(.system(size: max(6, rowHeight * 0.9))).foregroundStyle(.secondary)
        )
        context.draw(
            pinOneLabel,
            at: CGPoint(x: leftContactX - socketRect.width * 0.02, y: chipTopY + contactHeight / 2),
            anchor: .trailing
        )
    }
}

#Preview {
    ChipPlacementView(placement: ChipPlacement(pinCount: 28, socketPinCount: 40))
        .frame(height: 300)
        .padding()
}
