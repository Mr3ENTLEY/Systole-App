//
//  HueBridgeSetupView.swift
//  HomeHub
//

import SwiftUI

struct HueBridgeSetupView: View {
    @AppStorage("hue_bridge_ip") var bridgeIP: String = ""
    @AppStorage("hue_token") var token: String = ""

    @State private var isDiscovering = false
    @State private var isRegistering = false
    @State private var statusMessage = "Let's get you setup!"
    @State private var bridgeFound = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "play.house.fill")
                .font(.system(size: 80))
                .foregroundColor(bridgeFound ? .yellow : .gray)

            Text("Home Hub")
                .font(.largeTitle.bold())
                .textCase(.uppercase)

            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if isDiscovering || isRegistering {
                ProgressView()
            }

            if !bridgeFound {
                Button("Discover Bridge") {
                    Task { await discoverBridge() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDiscovering)
            }

            if bridgeFound && token.isEmpty {
                VStack(spacing: 12) {
                    Text("Press the button on top of your Hue Bridge, then tap below.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Authenticate") {
                        Task { await authenticate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRegistering)
                }
            }

            Spacer()
        }
        .padding()
    }

    func discoverBridge() async {
        isDiscovering = true
        statusMessage = "Searching for Hue Bridge..."

        do {
            let url = URL(string: "https://discovery.meethue.com")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let bridges = try JSONDecoder().decode([HueBridgeInfo].self, from: data)

            if let bridge = bridges.first {
                bridgeIP = bridge.internalipaddress
                bridgeFound = true
                statusMessage = "Bridge found at \(bridge.internalipaddress)!"
            } else {
                statusMessage = "No bridge found. Make sure you're on the same WiFi."
            }
        } catch {
            statusMessage = "Discovery failed: \(error.localizedDescription)"
        }

        isDiscovering = false
    }

    func authenticate() async {
        isRegistering = true
        statusMessage = "Authenticating..."

        do {
            let url = URL(string: "http://\(bridgeIP)/api")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(
                withJSONObject: ["devicetype": "HomeHub#iPhone"]
            )

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]

            if let success = response.first?["success"] as? [String: Any],
               let username = success["username"] as? String {
                token = username
                // HomeHubApp watches token, will auto-navigate to ContentView
            } else if let error = response.first?["error"] as? [String: Any] {
                let desc = error["description"] as? String ?? "Unknown error"
                statusMessage = "Error: \(desc)"
            }
        } catch {
            statusMessage = "Authentication failed: \(error.localizedDescription)"
        }

        isRegistering = false
    }
}

struct HueBridgeInfo: Decodable {
    let internalipaddress: String
}

#Preview {
    HueBridgeSetupView()
}
