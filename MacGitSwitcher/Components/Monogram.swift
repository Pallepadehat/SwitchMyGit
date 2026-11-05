import SwiftUI
import SwitchMyGitCore

/// A Contacts-style grey circle with the profile's initials.
struct Monogram: View {
    let profile: GitProfile
    var size: CGFloat = 28

    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color(white: 0.66), Color(white: 0.52)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay {
                Text(profile.initials)
                    .font(.system(size: size * 0.42, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
