import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var profileStore = UserProfileStore.shared
    
    @State private var userName: String = ""
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.background
                    .edgesIgnoringSafeArea(.all)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile image section
                        VStack(spacing: 16) {
                            // Profile image with edit button
                            ZStack(alignment: .bottomTrailing) {
                                ProfileImageView(image: profileStore.profileImage, size: 120)
                                    .padding(.top, 20)
                                
                                Button(action: {
                                    isShowingPhotoPicker = true
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.primaryGreen)
                                            .frame(width: 36, height: 36)
                                        
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                                .offset(x: 5, y: 5)
                            }
                            
                            // Remove photo button (only if there's a photo)
                            if profileStore.profileImage != nil {
                                Button(action: {
                                    profileStore.clearProfileImage()
                                }) {
                                    Text("Remove Photo")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Name")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.textSecondary)
                            
                            TextField("Enter your name", text: $userName)
                                .font(.system(.body, design: .rounded))
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        
                        // Save button
                        Button(action: {
                            saveProfile()
                        }) {
                            Text("Save Profile")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primaryGreen)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitle("Edit Profile", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                // Load current values
                userName = profileStore.userName
            }
            .photosPicker(
                isPresented: $isShowingPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { oldValue, newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            // Process image to ensure it's not too large
                            let processedImage = processImage(image)
                            
                            // Update on main thread
                            DispatchQueue.main.async {
                                profileStore.saveProfileImage(processedImage)
                                selectedPhotoItem = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        // Save user name if changed
        if !userName.isEmpty && userName != profileStore.userName {
            profileStore.saveUserName(userName)
        }
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
    
    // Process image to ensure it's not too large
    private func processImage(_ image: UIImage) -> UIImage {
        let maxSize: CGFloat = 500
        
        // Check if resizing is needed
        if image.size.width <= maxSize && image.size.height <= maxSize {
            return image
        }
        
        // Calculate new size while maintaining aspect ratio
        let aspectRatio = image.size.width / image.size.height
        var newSize: CGSize
        
        if aspectRatio > 1 {
            // Landscape
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            // Portrait
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // Create a new image context
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
} 