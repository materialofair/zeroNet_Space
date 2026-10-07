import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var ink: Color {
        isDark ? Color(red: 0.93, green: 0.92, blue: 0.86)
            : Color(red: 0.06, green: 0.28, blue: 0.28)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [Color(red: 0.025, green: 0.13, blue: 0.14), Color(red: 0.02, green: 0.08, blue: 0.09)]
                        : [Color(red: 0.97, green: 0.96, blue: 0.93), Color(red: 0.89, green: 0.94, blue: 0.91)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 26) {
                        Image("AppIconDisplay")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(geometry.size.width * 0.28, 128), height: min(geometry.size.width * 0.28, 128))
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(isDark ? 0.22 : 0.12), radius: 24, y: 12)

                        VStack(spacing: 10) {
                            Text("ZeroNet Space")
                                .font(.system(size: 28, weight: .medium, design: .serif))
                                .tracking(0.4)
                            Text(String(localized: "launch.brand.subtitle"))
                                .font(.subheadline)
                                .foregroundStyle(ink.opacity(0.65))
                        }
                    }
                    .foregroundStyle(ink)
                    .padding(.horizontal, 32)
                    Spacer()
                    Text("Z E R O N E T")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ink.opacity(0.4))
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 28) + 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("launch.brand")
    }
}

#Preview {
    LaunchScreenView()
}
