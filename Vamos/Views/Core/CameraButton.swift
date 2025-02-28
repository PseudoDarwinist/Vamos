import SwiftUI

struct CameraButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient.greenToTeal)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.primaryGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 62, height: 62)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
    }
}

struct FloatingCameraButton: View {
    var action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                CameraButton(action: action)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct CameraButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.background.edgesIgnoringSafeArea(.all)
            
            CameraButton {
                print("Camera button tapped")
            }
        }
        .previewLayout(.fixed(width: 200, height: 200))
    }
}