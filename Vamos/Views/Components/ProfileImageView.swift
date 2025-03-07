import SwiftUI

struct ProfileImageView: View {
    let image: UIImage?
    let size: CGFloat
    let showBorder: Bool
    
    init(image: UIImage?, size: CGFloat = 40, showBorder: Bool = true) {
        self.image = image
        self.size = size
        self.showBorder = showBorder
    }
    
    var body: some View {
        ZStack {
            if let profileImage = image {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Placeholder
                Circle()
                    .fill(Color.secondaryGreen.opacity(0.3))
                    .frame(width: size, height: size)
                
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.primaryGreen)
            }
        }
        .overlay(
            Group {
                if showBorder {
                    Circle()
                        .stroke(Color.primaryGreen, lineWidth: 2)
                }
            }
        )
    }
}

struct ProfileImageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Without image
            ProfileImageView(image: nil, size: 60)
            
            // With image (would use a real image in a real app)
            ProfileImageView(image: UIImage(systemName: "person.fill"), size: 60)
            
            // Smaller size
            ProfileImageView(image: nil, size: 40)
            
            // Without border
            ProfileImageView(image: nil, size: 50, showBorder: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 