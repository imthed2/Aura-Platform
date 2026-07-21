import Foundation

enum AuraSettingsKey: String, Sendable {
    case selectedTab
    case hapticsEnabled
}

protocol SettingsRepository: Sendable {
    func string(for key: AuraSettingsKey) async -> String?
    func bool(for key: AuraSettingsKey) async -> Bool?
    func set(_ value: String, for key: AuraSettingsKey) async
    func set(_ value: Bool, for key: AuraSettingsKey) async
}

actor UserDefaultsSettingsRepository: SettingsRepository {
    private let defaults: UserDefaults

    init(suiteName: String = "com.danielhagen.aura.settings") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func string(for key: AuraSettingsKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    func bool(for key: AuraSettingsKey) -> Bool? {
        guard defaults.object(forKey: key.rawValue) != nil else { return nil }
        return defaults.bool(forKey: key.rawValue)
    }

    func set(_ value: String, for key: AuraSettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    func set(_ value: Bool, for key: AuraSettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }
}

actor InMemorySettingsRepository: SettingsRepository {
    private var values: [AuraSettingsKey: String] = [:]

    func string(for key: AuraSettingsKey) -> String? {
        values[key]
    }

    func bool(for key: AuraSettingsKey) -> Bool? {
        values[key].flatMap(Bool.init)
    }

    func set(_ value: String, for key: AuraSettingsKey) {
        values[key] = value
    }

    func set(_ value: Bool, for key: AuraSettingsKey) {
        values[key] = String(value)
    }
}

