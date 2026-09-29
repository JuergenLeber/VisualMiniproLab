//
//  ChipProgrammingView.swift
//  MiniproUI
//
//  Created by Pawel Kadluczka on 3/27/25.
//

import SwiftUI

struct ChipProgrammingView: View {
    /// Keeps the chip list, the details and the banners from being squeezed
    /// out of the window by the hex view next to them.
    private static let sideColumnMinWidth: CGFloat = 340
    /// What the three columns need side by side: the hex view at its narrowest,
    /// the read and write buttons, the column above, and the padding around
    /// them. Stated so the window cannot shrink past it and let the columns
    /// spill out from under the sidebar.
    private static let contentMinWidth: CGFloat = 320 + 80 + sideColumnMinWidth + 40

    @ObservedObject var model: MiniproModel

    var body: some View {
        let needsAlgorithms = AlgorithmXmlUtils.needsAlgorithmInstallation(programmerInfo: model.programmerInfo)
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                TabHeaderView(
                    caption: "Selected Chip: " + selectedChipCaption,
                    systemImageName: "memorychip.fill"
                )
                HStack {
                    VStack {
                        BinaryDataView(data: $model.buffer)
                            .frame(minWidth: 320, idealWidth: 678)
                        HStack {
                            OpenFileButton(caption: "Open File") { url in
                                model.buffer = try Data(contentsOf: url)
                            }
                            SaveFileButton { url in
                                try model.buffer?.write(to: url)
                            }
                            .disabled(model.buffer == nil)
                        }
                        Spacer()
                    }
                    VStack {
                        ReadChipButton(
                            device: model.deviceDetails,
                            buffer: $model.buffer,
                            readOptions: $model.readOptions,
                            programmerInfo: $model.programmerInfo,
                            infoicOverride: model.selectedChipInfoicPath
                        )
                        WriteChipButton(
                            device: model.deviceDetails,
                            buffer: model.buffer,
                            writeOptions: $model.writeOptions,
                            programmerInfo: $model.programmerInfo,
                            infoicOverride: model.selectedChipInfoicPath
                        )
                    }
                    let supportedEEPROMs = model.supportedDevices?.eepromChips ?? []
                    if needsAlgorithms {
                        VStack {
                            Form {
                                MissingAlgorithms()
                            }
                            .formStyle(.grouped)
                            .padding(.top, 32)
                        }
                        .frame(minWidth: Self.sideColumnMinWidth)
                    } else if model.programmerInfo == nil {
                        VStack {
                            Form {
                                ProgrammerNotConnected()
                            }
                            .formStyle(.grouped)
                            .padding(.top, 32)
                        }
                        .frame(minWidth: Self.sideColumnMinWidth)
                    } else {
                        ZStack {
                            VStack {
                                if model.deviceDetails != nil {
                                    DeviceDetailsView(
                                        expectLogicChip: false,
                                        deviceDetails: $model.deviceDetails,
                                        programmerModel: model.programmerInfo?.model,
                                        variant: model.selectedChip?.variant
                                    )
                                        .padding(.top, 32)
                                    Spacer()
                                }
                            }
                            VStack {
                                SearchableListView(
                                    items: supportedEEPROMs,
                                    selectedItem: $model.selectedChip,
                                    applyAdditionalFilter: $model.applyFavoriteFilter,
                                    isCollapsible: true,
                                    additionalFilter: filterFavoriteChips
                                )
                                .frame(maxWidth: 658, maxHeight: 600)
                                .padding([.trailing])
                                Spacer()
                            }
                        }
                        .frame(minWidth: Self.sideColumnMinWidth)
                    }
                }
                .padding()
                Spacer()
            }
        }
        .frame(minWidth: Self.contentMinWidth)
        .task {
            model.programmerInfo = try? await MiniproAPI.getProgrammerInfo()
            if let programmerInfo = model.programmerInfo {
                let infoicPath = InfoICUtils.resolveInfoICPath(for: programmerInfo.model)
                model.supportedDevices = try? await MiniproAPI.getSupportedDevices(
                    infoicPath: infoicPath,
                    programmerModel: programmerInfo.model
                )
            }
        }
        .onChange(of: model.selectedChip) {
            Task {
                guard let chip = model.selectedChip, let programmerInfo = model.programmerInfo else {
                    return
                }
                // A name several manufacturers declare needs a database holding
                // only the chosen one - minipro would load the first match.
                let infoicPath = ChipVariantOverride.infoicPath(
                    for: chip,
                    catalog: model.supportedDevices?.catalog ?? .empty,
                    fallback: InfoICUtils.resolveInfoICPath(for: programmerInfo.model)
                )
                model.selectedChipInfoicPath = infoicPath
                model.deviceDetails = try? await MiniproAPI.getDeviceDetails(
                    device: chip.name, infoicPath: infoicPath)
            }
        }
    }

    /// The manufacturer belongs in the header: once a chip is picked the list
    /// collapses to its name and the details sit behind it.
    private var selectedChipCaption: String {
        guard let chip = model.selectedChip else {
            return "None"
        }
        return [chip.name, chip.manufacturerLabel].compactMap { $0 }.joined(separator: " · ")
    }

    func filterFavoriteChips(_ supportedEEPROMs: [ChipListItem]) -> [ChipListItem] {
        let favoriteChips = UserDefaults.standard.favoriteChips
        let filteredChips = supportedEEPROMs.filter { eeprom in
            favoriteChips.contains { eeprom.name.lowercased().contains($0.lowercased()) }
        }
        return filteredChips.isEmpty ? supportedEEPROMs : filteredChips
    }
}

struct ReadChipButton: View {
    let device: DeviceDetails?
    @Binding var buffer: Data?
    @Binding var readOptions: ReadOptions
    @Binding var programmerInfo: ProgrammerInfo?
    let infoicOverride: URL?
    @State private var errorMessage: DialogErrorMessage?
    @State private var isPresented = false

    var body: some View {
        Button(" << ") {
            isPresented = device != nil
        }
        .disabled(device?.isLogicChip ?? true)
        .sheet(isPresented: $isPresented) {
            ModalDialogView {
                ReadChipView(
                    device: device!,
                    buffer: $buffer,
                    isPresented: $isPresented,
                    readOptions: $readOptions,
                    programmerInfo: $programmerInfo,
                    infoicOverride: infoicOverride,
                    errorMessage: $errorMessage
                )
            }
        }
        .alert(item: $errorMessage) {
            Alert(
                title: Text("Reading Chip Contents Failed"),
                message: Text($0.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct WriteChipButton: View {
    let device: DeviceDetails?
    let buffer: Data?
    @Binding var writeOptions: WriteOptions
    @Binding var programmerInfo: ProgrammerInfo?
    let infoicOverride: URL?
    @State private var isPresented = false
    @State private var errorMessage: DialogErrorMessage?

    var body: some View {
        Button(" >> ") {
            isPresented = device != nil && buffer != nil
        }
        .disabled(device?.isLogicChip ?? true || buffer == nil)
        .sheet(isPresented: $isPresented) {
            ModalDialogView {
                WriteChipView(
                    device: device!,
                    buffer: buffer!,
                    isPresented: $isPresented,
                    writeOptions: $writeOptions,
                    programmerInfo: $programmerInfo,
                    infoicOverride: infoicOverride,
                    errorMessage: $errorMessage
                )
            }
        }
        .alert(item: $errorMessage) {
            Alert(
                title: Text("Write Failure"),
                message: Text($0.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ChipProgrammingView(model: MiniproModel())
}
