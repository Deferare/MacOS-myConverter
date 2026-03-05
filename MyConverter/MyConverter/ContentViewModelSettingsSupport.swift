import Foundation

enum ContentViewModelSettingsDefaults {
    static var defaultVideoFormatID: String {
        ContentViewModelSupport.defaultVideoFormat().id
    }

    static var defaultAudioFormatID: String {
        ContentViewModelSupport.defaultAudioFormat().id
    }
}

extension KeyedDecodingContainer {
    func decodeRequiredString(forKey key: Key) throws -> String {
        try decode(String.self, forKey: key)
    }

    func decodeString(forKey key: Key, default defaultValue: String) throws -> String {
        try decodeIfPresent(String.self, forKey: key) ?? defaultValue
    }

    func decodeBool(forKey key: Key, default defaultValue: Bool) throws -> Bool {
        try decodeIfPresent(Bool.self, forKey: key) ?? defaultValue
    }
}

func restoredOption<Option: RawRepresentable>(
    _ rawValue: String,
    default defaultValue: Option
) -> Option where Option.RawValue == String {
    Option(rawValue: rawValue) ?? defaultValue
}
