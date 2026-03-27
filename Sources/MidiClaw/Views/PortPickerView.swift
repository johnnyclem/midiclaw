#if os(macOS)
import SwiftUI
import MidiClawCore

/// View to select and connect MIDI sources and destinations.
struct PortPickerView: View {
    @ObservedObject var appState: AppState
    @State private var connectedSourceIds: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MIDI Ports")
                .font(.title2)

            // Sources
            Section {
                if appState.availableSources.isEmpty {
                    Text("No MIDI sources available")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(appState.availableSources) { source in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source.name)
                                    .font(.body)
                                if !source.manufacturer.isEmpty {
                                    Text(source.manufacturer)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()

                            if source.isVirtual {
                                Text("Virtual")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }

                            Toggle("", isOn: Binding(
                                get: { connectedSourceIds.contains(source.id) },
                                set: { connected in
                                    if connected {
                                        connectedSourceIds.insert(source.id)
                                    } else {
                                        connectedSourceIds.remove(source.id)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Label("Sources (Input)", systemImage: "arrow.down.circle")
                    .font(.headline)
            }

            Divider()

            // Destinations
            Section {
                if appState.availableDestinations.isEmpty {
                    Text("No MIDI destinations available")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(appState.availableDestinations) { dest in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(dest.name)
                                    .font(.body)
                                if !dest.manufacturer.isEmpty {
                                    Text(dest.manufacturer)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()

                            if dest.isVirtual {
                                Text("Virtual")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Label("Destinations (Output)", systemImage: "arrow.up.circle")
                    .font(.headline)
            }

            Spacer()

            Button("Refresh Ports") {
                appState.refreshMIDIPorts()
            }
        }
        .padding()
    }
}
#endif
