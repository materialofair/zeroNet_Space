//
//  MediaView.swift
//  ZeroNet-Space
//
//  影音视图（合并视频与音频两个子标签）
//

import SwiftUI

struct MediaView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthenticationViewModel

    // MARK: - State

    @State private var selectedSection = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if selectedSection == 0 {
                    VideosView()
                        .environmentObject(authViewModel)
                } else {
                    AudioView()
                }
            }
            .navigationTitle(String(localized: "tab.media"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedSection) {
                        Text(String(localized: "tab.videos")).tag(0)
                        Text(String(localized: "tab.audio")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MediaView()
        .environmentObject(AuthenticationViewModel())
}
