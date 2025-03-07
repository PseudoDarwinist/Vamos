import SwiftUI
import Combine

class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()
    
    @Published var userName: String = "User"
    @Published var profileImage: UIImage?
    
    private let userDefaults = UserDefaults.standard
    private let profileImageKey = "userProfileImage"
    private let userNameKey = "userName"
    
    private init() {
        loadUserData()
    }
    
    func loadUserData() {
        // Load user name
        if let savedName = userDefaults.string(forKey: userNameKey) {
            userName = savedName
        }
        
        // Load profile image
        if let imageData = userDefaults.data(forKey: profileImageKey),
           let image = UIImage(data: imageData) {
            profileImage = image
        }
    }
    
    func saveUserName(_ name: String) {
        userName = name
        userDefaults.set(name, forKey: userNameKey)
    }
    
    func saveProfileImage(_ image: UIImage) {
        profileImage = image
        
        // Compress and save the image data
        if let imageData = image.jpegData(compressionQuality: 0.7) {
            userDefaults.set(imageData, forKey: profileImageKey)
        }
    }
    
    func clearProfileImage() {
        profileImage = nil
        userDefaults.removeObject(forKey: profileImageKey)
    }
} 