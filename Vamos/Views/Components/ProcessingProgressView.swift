import SwiftUI
import SpriteKit

// MARK: - Main Processing Progress View
struct ProcessingProgressView: View {
    @Binding var progress: Double // 0...1
    @State private var statusText = "Processing statement..."
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Progress animation container
            ZStack {
                PieChart(progress: $progress)
                ReceiptIcon(progress: $progress)
                ProgressRing(progress: $progress)
            }
            .frame(width: 180, height: 180)
            
            // Status labels
            VStack(spacing: 8) {
                Text(statusText)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("\(Int(progress * 100))%")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
        )
        .overlay(
            showConfetti ? ConfettiView() : nil
        )
        .onAppear {
            // Trigger confetti if we appear with 100% progress
            if progress >= 1.0 {
                successSequence()
            }
        }
        .onChange(of: progress) { newValue in
            updateStatusText(for: newValue)
            
            if newValue >= 1.0 {
                successSequence()
            }
        }
    }
    
    private func updateStatusText(for progress: Double) {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch progress {
            case 0.0..<0.05:
                statusText = "Loading document..."
            case 0.05..<0.30:
                statusText = "Converting PDF to images..."
            case 0.30..<0.70:
                statusText = "Extracting text with OCR..."
            case 0.70..<0.95:
                statusText = "Processing with AI..."
            case 0.95..<1.0:
                statusText = "Almost done..."
            default:
                statusText = "Complete!"
            }
        }
    }
    
    private func successSequence() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show confetti
        showConfetti = true
        
        // Hide confetti after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            showConfetti = false
        }
    }
}

// MARK: - Pie Chart Component
struct PieChart: View {
    @Binding var progress: Double
    
    private let sliceColors: [Color] = [
        Color(red: 0.0, green: 0.42, blue: 1.0),    // brand.blue #006CFF
        Color(red: 1.0, green: 0.32, blue: 0.32),   // brand.red #FF5252
        Color(red: 1.0, green: 0.77, blue: 0.0),    // brand.yellow #FFC400
        Color(red: 0.0, green: 0.77, blue: 0.55)    // brand.green #00C48C
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<4) { index in
                let sliceProgress = max(0, min(1, progress * 4 - Double(index)))
                
                Circle()
                    .trim(from: CGFloat(index) * 0.25, to: CGFloat(index) * 0.25 + CGFloat(sliceProgress) * 0.25)
                    .stroke(sliceColors[index], lineWidth: 35)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(sliceProgress > 0 ? 1.0 : 0.0)
                    .animation(
                        .interpolatingSpring(mass: 0.5, stiffness: 100, damping: 15)
                        .delay(Double(index) * 0.1),
                        value: sliceProgress
                    )
            }
        }
        .frame(width: 140, height: 140)
    }
}

// MARK: - Progress Ring
struct ProgressRing: View {
    @Binding var progress: Double
    @State private var animatedProgress: Double = 0.0
    @State private var lastUpdateTime: Date = Date()
    @State private var pulseTimer: Timer?
    
    var body: some View {
        Circle()
            .trim(from: 0, to: animatedProgress)
            .stroke(
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            .foregroundColor(Color(red: 0.11, green: 0.16, blue: 0.2)) // neutral.ink #1C2833
            .rotationEffect(.degrees(-90))
            .frame(width: 160, height: 160)
            .onAppear {
                startProgressAnimation()
            }
            .onChange(of: progress) { newProgress in
                updateProgress(to: newProgress)
            }
            .onDisappear {
                stopProgressAnimation()
            }
    }
    
    private func startProgressAnimation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            animatedProgress = progress
        }
        lastUpdateTime = Date()
        startPulseAnimation()
    }
    
    private func updateProgress(to newProgress: Double) {
        withAnimation(.easeInOut(duration: 0.5)) {
            animatedProgress = newProgress
        }
        lastUpdateTime = Date()
        
        // If progress is complete, stop pulsing
        if newProgress >= 1.0 {
            stopProgressAnimation()
        } else {
            // Restart pulse animation for new progress level
            startPulseAnimation()
        }
    }
    
    private func startPulseAnimation() {
        stopProgressAnimation() // Stop any existing timer
        
        // Start a timer that will create the pulse effect if progress hasn't changed
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateTime)
            
            // If no progress update for 1.5 seconds and not complete, start pulsing
            if timeSinceLastUpdate > 1.5 && progress < 1.0 && progress > 0 {
                startPulseEffect()
            }
        }
    }
    
    private func startPulseEffect() {
        // Animate from 0 to current progress continuously
        withAnimation(.easeInOut(duration: 2.0)) {
            animatedProgress = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 2.0)) {
                animatedProgress = progress
            }
        }
    }
    
    private func stopProgressAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}

// MARK: - Receipt Icon
struct ReceiptIcon: View {
    @Binding var progress: Double
    
    var body: some View {
        Image(systemName: "receipt")
            .font(.system(size: 60, weight: .light))
            .foregroundColor(.secondary)
            .opacity(max(0, 1 - progress * 1.5))
            .offset(x: -20 * progress, y: 0)
            .scaleEffect(0.8 + 0.2 * (1 - progress))
            .animation(
                .easeOut(duration: 0.6),
                value: progress
            )
    }
}

// MARK: - Confetti View
struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.isUserInteractionEnabled = false
        
        let scene = SKScene(size: CGSize(width: 400, height: 600))
        scene.backgroundColor = .clear
        
        // Create multiple colored emitters for confetti
        let colors: [UIColor] = [
            UIColor.systemBlue,
            UIColor.systemRed,
            UIColor.systemYellow,
            UIColor.systemGreen,
            UIColor.systemPurple,
            UIColor.systemOrange,
            UIColor.systemPink,
            UIColor.systemTeal
        ]
        
        for (index, color) in colors.enumerated() {
            let emitter = SKEmitterNode()
            
            // Create a simple circle texture
            let size = CGSize(width: 10, height: 10)
            let renderer = UIGraphicsImageRenderer(size: size)
            let circleImage = renderer.image { context in
                color.setFill()
                context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            }
            
            emitter.particleTexture = SKTexture(image: circleImage)
            emitter.particleBirthRate = 50
            emitter.particleLifetime = 4.0
            emitter.particleLifetimeRange = 2.0
            emitter.emissionAngle = .pi / 2  // Downward
            emitter.emissionAngleRange = .pi / 2  // Wider spread
            emitter.particleSpeed = 200
            emitter.particleSpeedRange = 150
            emitter.particleScale = 0.8
            emitter.particleScaleRange = 0.5
            emitter.particleScaleSpeed = -0.3
            emitter.particleAlpha = 1.0
            emitter.particleAlphaSpeed = -0.25
            emitter.particleColor = color
            
            // Position emitters across the top
            emitter.position = CGPoint(
                x: scene.size.width / 2 + CGFloat(index - 3) * 30,
                y: scene.size.height + 50
            )
            
            // Gravity and movement
            emitter.yAcceleration = -300
            emitter.xAcceleration = CGFloat.random(in: -80...80)
            emitter.particleRotation = 0
            emitter.particleRotationRange = .pi * 2
            emitter.particleRotationSpeed = CGFloat.random(in: -5...5)
            
            scene.addChild(emitter)
            
            // Auto-remove after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                emitter.removeFromParent()
            }
        }
        
        view.presentScene(scene)
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {}
}

// MARK: - Preview
struct ProcessingProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            ProcessingProgressView(progress: .constant(0.3))
            ProcessingProgressView(progress: .constant(0.7))
            ProcessingProgressView(progress: .constant(1.0))
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
} 