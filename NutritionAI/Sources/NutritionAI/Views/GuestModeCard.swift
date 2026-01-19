import SwiftUI

struct GuestModeCard: View {
    let onSignUp: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(AppGradients.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Guest mode")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Your data stays on this device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onSignUp) {
                Text("Create account")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppGradients.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassMorphism(cornerRadius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#if DEBUG
struct GuestModeCard_Previews: PreviewProvider {
    static var previews: some View {
        GuestModeCard(onSignUp: {})
            .padding()
    }
}
#endif