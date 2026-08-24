//
//  DeviceDetailsView.swift
//  MiniproUI
//
//  Created by Pawel Kadluczka on 2/11/25.
//

import SwiftUI

struct DeviceDetailsView: View {
    let expectLogicChip: Bool
    @Binding var deviceDetails: DeviceDetails?
    var programmerModel: ProgrammerModel? = nil
    @State private var enlargedItem: ChipIllustration? = nil

    var body: some View {
        let illustrations = illustrations()
        VStack(alignment: .leading) {
            Form {
                if let deviceDetails = deviceDetails {
                    Section(header: Text("\(deviceDetails.name) Details")) {
                        ForEach(deviceDetails.deviceInfo, id: \.self) { info in
                            PropertyRow(label: info.key, value: info.value)
                        }
                        if expectLogicChip != deviceDetails.isLogicChip {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                Text(
                                    "\(deviceDetails.name) is not a \(expectLogicChip ? "logic" : "programmable") chip"
                                )
                                .fontWeight(.medium)
                            }
                        }
                        ForEach(illustrations) { illustration in
                            ChipIllustrationRow(illustration: illustration) {
                                enlargedItem = illustration
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: computeHeight(illustrationCount: illustrations.count))
        }
        .sheet(item: $enlargedItem) { illustration in
            ModalDialogView {
                ChipIllustrationDetailsView(illustration: illustration) {
                    enlargedItem = nil
                }
            }
        }
    }

    private func illustrations() -> [ChipIllustration] {
        guard let deviceDetails, let programmerModel else {
            return []
        }
        let photos = XgproImageUtils.chipImages(for: deviceDetails, programmerModel: programmerModel)
            .map { ChipIllustration.photo($0) }
        // Adapters get both: the picture of the adapter and where it goes.
        let placement = ChipPlacementUtils.placement(for: deviceDetails, programmerModel: programmerModel)
            .map { ChipIllustration.placement($0) }
        return photos + (placement.map { [$0] } ?? [])
    }

    private func computeHeight(illustrationCount: Int) -> CGFloat {
        if let deviceDetails = deviceDetails {
            let imagesHeight = CGFloat(illustrationCount) * (ChipIllustrationRow.thumbnailHeight + 48)
            if !deviceDetails.isLogicChip {
                return 400 + imagesHeight
            }
            // account for the additional warning row
            return 220 + (expectLogicChip ? 0 : 30) + imagesHeight
        }
        return 0
    }
}

enum ChipIllustration: Identifiable, Equatable {
    case photo(ChipImage)
    case placement(ChipPlacement)

    var id: String {
        switch self {
        case .photo(let chipImage):
            return chipImage.id
        case .placement(let placement):
            return "placement-DIP\(placement.pinCount)"
        }
    }

    var caption: String {
        switch self {
        case .photo(let chipImage):
            return chipImage.caption
        case .placement:
            return "Location in Socket"
        }
    }
}

private struct ChipIllustrationRow: View {
    static let thumbnailHeight: CGFloat = 120

    let illustration: ChipIllustration
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(illustration.caption)
            Button(action: onSelect) {
                ChipIllustrationView(illustration: illustration)
                    .frame(maxWidth: .infinity, maxHeight: Self.thumbnailHeight)
            }
            .buttonStyle(.plain)
            .help("Click to enlarge")
            if case .placement(let placement) = illustration {
                Text(
                    [placement.socketName, placement.adapterName.map { "\($0) adapter" }]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ChipIllustrationDetailsView: View {
    let illustration: ChipIllustration
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(illustration.caption)
                .font(.headline)
            ChipIllustrationView(illustration: illustration)
                .frame(maxWidth: 700, maxHeight: 500)
            if case .placement(let placement) = illustration {
                Text(placementDescription(placement))
                .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            Button("Close", action: onClose)
                .keyboardShortcut(.defaultAction)
        }
    }
}

private func placementDescription(_ placement: ChipPlacement) -> String {
    let target =
        placement.adapterName.map { "Put the chip in a \($0) adapter and place the adapter" }
        ?? "Insert the DIP\(placement.pinCount) chip"
    return
        "\(target) at the bottom of the \(placement.socketName) socket, notch pointing up. "
        + "Pin 1 goes in socket pin \(placement.firstSocketPin)."
}

private struct ChipIllustrationView: View {
    let illustration: ChipIllustration

    var body: some View {
        switch illustration {
        case .photo(let chipImage):
            ChipImageView(url: chipImage.url)
        case .placement(let placement):
            ChipPlacementView(placement: placement)
        }
    }
}

private struct ChipImageView: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            ProgressView()
        }
    }
}

#Preview {
    DeviceDetailsView(
        expectLogicChip: true,
        deviceDetails: .constant(DeviceDetails(name: "7400", deviceInfo: [], programmingInfo: [], isLogicChip: true)))
}
