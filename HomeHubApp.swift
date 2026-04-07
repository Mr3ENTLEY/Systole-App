//
//  HomeHubApp.swift
//  HomeHub
//

import SwiftUI

@main
struct HomeHubApp: App {
    @AppStorage("hue_token") var token: String = ""
    @AppStorage("hue_bridge_ip") var bridgeIP: String = ""

    var body: some Scene {
        WindowGroup {
            if token.isEmpty || bridgeIP.isEmpty {
                HueBridgeSetupView()
            } else {
                ContentView()
            }
        }
    }
}
