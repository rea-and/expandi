import AppKit

public final class SoundPlayer: Sendable {
    public static let shared = SoundPlayer()
    
    public init() {}
    
    public func playExpansionSound(soundName: String = "Tink") {
        DispatchQueue.main.async {
            if let sound = NSSound(named: NSSound.Name(soundName)) {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }
}
