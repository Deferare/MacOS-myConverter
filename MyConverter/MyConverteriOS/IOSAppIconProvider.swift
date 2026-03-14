#if os(iOS)
import UIKit

enum IOSAppIconProvider {
    static func primaryIconImage(bundle: Bundle = .main) -> UIImage? {
        let infoDictionaryKeys: [String]
        if UIDevice.current.userInterfaceIdiom == .pad {
            infoDictionaryKeys = ["CFBundleIcons~ipad", "CFBundleIcons"]
        } else {
            infoDictionaryKeys = ["CFBundleIcons", "CFBundleIcons~ipad"]
        }

        for key in infoDictionaryKeys {
            guard
                let icons = bundle.object(forInfoDictionaryKey: key) as? [String: Any],
                let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
                let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
            else {
                continue
            }

            for iconFile in iconFiles.reversed() {
                if let image = UIImage(named: iconFile) {
                    return image
                }
            }
        }

        return nil
    }
}
#endif
