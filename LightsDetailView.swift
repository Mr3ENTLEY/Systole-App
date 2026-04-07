//
//  LightDetailView.swift
//  HomeHub
//

import SwiftUI

struct LightDetailView: View {
    let light: HueLight
    let onUpdate: () -> Void

    @AppStorage("hue_bridge_ip") var bridgeIP: String = ""
    @AppStorage("hue_token") var token: String = ""

    @State private var isOn: Bool
    @State private var brightness: Double
    @State private var selectedColor: Color
    @State private var isSending = false

    let presets: [(name: String, hue: Int, sat: Int, color: Color)] = [
        ("Warm White",  6000,  50,  Color(hue: 0.09, saturation: 0.3,  brightness: 1)),
        ("Cool White",  41000, 30,  Color(hue: 0.56, saturation: 0.2,  brightness: 1)),
        ("Red",         0,     254, .red),
        ("Orange",      6000,  254, .orange),
        ("Yellow",      12000, 254, .yellow),
        ("Green",       25000, 254, .green),
        ("Cyan",        36000, 254, Color(hue: 0.5, saturation: 1, brightness: 1)),
        ("Blue",        46000, 254, .blue),
        ("Purple",      50000, 254, .purple),
        ("Pink",        56000, 254, .pink),
    ]

    init(light: HueLight, onUpdate: @escaping () -> Void) {
        self.light = light
        self.onUpdate = onUpdate
        _isOn = State(initialValue: light.on)
        _brightness = State(initialValue: Double(light.brightness) / 254.0)
        _selectedColor = State(initialValue: Color(
            hue: Double(light.hue) / 65535.0,
            saturation: Double(light.saturation) / 254.0,
            brightness: 1.0
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Light preview circle
                ZStack {
                    Circle()
                        .fill(isOn ? selectedColor.opacity(brightness) : Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .shadow(color: isOn ? selectedColor.opacity(0.6) : .clear, radius: 20)

                    Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 40))
                        .foregroundColor(isOn ? .white : .gray)
                }
                .padding(.top, 10)
                .animation(.easeInOut(duration: 0.3), value: isOn)
                .animation(.easeInOut(duration: 0.3), value: selectedColor)

                // Power toggle
                HStack {
                    Text("Power")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .onChange(of: isOn) { _, newValue in
                            Task { await sendState(["on": newValue]) }
                        }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Brightness slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Brightness")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(brightness * 100))%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.secondary)
                        Slider(value: $brightness, in: 0.01...1.0)
                            .accentColor(selectedColor)
                            .onChange(of: brightness) { _, newValue in
                                Task { await sendState(["bri": Int(newValue * 254)]) }
                            }
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Color picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Color")
                        .font(.headline)
                    ColorPicker("Pick a color", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .scaleEffect(1.4)
                        .frame(height: 50)
                        .onChange(of: selectedColor) { _, newColor in
                            Task { await sendColorFromSwiftUI(newColor) }
                        }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Preset swatches
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presets")
                        .font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(presets, id: \.name) { preset in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: preset.color.opacity(0.5), radius: 4)
                                    .onTapGesture {
                                        selectedColor = preset.color
                                        Task {
                                            await sendState([
                                                "on": true,
                                                "hue": preset.hue,
                                                "sat": preset.sat,
                                                "bri": Int(brightness * 254)
                                            ])
                                        }
                                        isOn = true
                                    }
                                Text(preset.name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(light.name)
        .navigationBarTitleDisplayMode(.large)
        .onDisappear { onUpdate() }
    }

    func sendState(_ body: [String: Any]) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            let url = URL(string: "http://\(bridgeIP)/api/\(token)/lights/\(light.id)/state")!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to send state: \(error)")
        }
    }

    func sendColorFromSwiftUI(_ color: Color) async {
        let ui = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        await sendState(["on": true, "hue": Int(h * 65535), "sat": Int(s * 254), "bri": Int(brightness * 254)])
        isOn = true
    }
}

#Preview {
    NavigationStack {
        LightDetailView(light: HueLight(id: "1", name: "Bedroom Lamp", on: true, brightness: 200, hue: 46000, saturation: 254), onUpdate: {})
    }
}
