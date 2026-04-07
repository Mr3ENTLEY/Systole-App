//
//  LightsView.swift
//  HomeHub
//

import SwiftUI

struct HueLight: Identifiable, Equatable {
    let id: String
    var name: String
    var on: Bool
    var brightness: Int      // 0–254
    var hue: Int             // 0–65535
    var saturation: Int      // 0–254
}

struct LightsView: View {
    @AppStorage("hue_bridge_ip") var bridgeIP: String = ""
    @AppStorage("hue_token") var token: String = ""

    @State private var lights: [HueLight] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading lights…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await fetchLights() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(lights) { light in
                                LightRow(light: light) {
                                    Task { await fetchLights() }
                                }
                            }
                        }
                        .animation(.snappy, value: lights)
                    }
                    .padding(20)
                }
                .refreshable {
                    await fetchLights()
                }
            }
        }
        .navigationTitle("Lights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Lights")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await fetchLights() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea(edges: .bottom)
        .task {
            await fetchLights()
        }
    }

    @MainActor
    func fetchLights() async {
        isLoading = true
        errorMessage = nil
        do {
            let url = URL(string: "http://\(bridgeIP)/api/\(token)/lights")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            var result: [HueLight] = []
            for (key, value) in raw {
                let dict = value as! [String: Any]
                let state = dict["state"] as! [String: Any]
                result.append(HueLight(
                    id: key,
                    name: dict["name"] as? String ?? "Unknown",
                    on: state["on"] as? Bool ?? false,
                    brightness: state["bri"] as? Int ?? 127,
                    hue: state["hue"] as? Int ?? 0,
                    saturation: state["sat"] as? Int ?? 0
                ))
            }
            lights = result.sorted { $0.name < $1.name }
        } catch {
            errorMessage = "Failed to load lights.\n\(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - LightRow

private struct LightRow: View {
    let light: HueLight
    let onUpdate: () -> Void

    var body: some View {
        NavigationLink(destination: LightDetailView(light: light, onUpdate: onUpdate)) {
            Card(
                icon: light.on ? "lightbulb.fill" : "lightbulb",
                title: light.name,
                color: light.on ? hueColor(light) : .gray
            )
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 12)
            }
        }
        .buttonStyle(.plain)
    }

    func hueColor(_ light: HueLight) -> Color {
        Color(hue: Double(light.hue) / 65535.0,
              saturation: Double(light.saturation) / 254.0,
              brightness: 1.0)
    }
}

// MARK: - Card

struct Card: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LightsView()
    }
}
