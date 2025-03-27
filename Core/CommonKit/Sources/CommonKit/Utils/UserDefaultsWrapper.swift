/// REF: https://gist.github.com/simonbs/61c8269e1b0550feab606ee9890fa72b
/**
 * I needed a property wrapper that fulfilled the following four requirements:
 *
 * 1. Values are stored in UserDefaults.
 * 2. Properties using the property wrapper can be used with SwiftUI.
 * 3. The property wrapper exposes a Publisher to be used with Combine.
 * 4. The publisher is only called when the value is updated and not
 *    when_any_ value stored in UserDefaults is updated.
 *
 * First I tried using SwiftUI's builtin @AppStorage property wrapper
 * but this doesn't provide a Publisher to be used with Combine.
 *
 * So I posted a tweet asking people how I can go about creating my own property wrapper:
 * https://twitter.com/simonbs/status/1387648636352348160
 *
 * A lot people replied but I didn't find a solution that was exactly what I wanted. Many suggestions came close
 * and based on those suggestions, I have implemented the property wrapper below.
 *
 * The main downside of this property wrapper is that it inherits from NSObject.
 * That's not very Swift-y but I can live wit that.
 */

// This is our property wrapper. Other types in this gist is just example usages of the property wrapper.
// The type inherits from NSObject to do old-fashined KVO without the KeyPath type.
//
// For simplicity sake the type in this gist only supports property list objects but can easily be combined
// with an approach similar to the one Jesse Squires takes in their Foil framework to support any type:
// https://github.com/jessesquires/Foil

import Foundation

@propertyWrapper
public final class UserDefaultStorage<T: Codable>: NSObject {
    // This ensures requirement 1 is fulfilled. The wrapped value is stored in user defaults.
    public var wrappedValue: T {
        get {
            if let data = userDefaults.data(forKey: key) {
                return (try? decoder.decode(T.self, from: data)) ?? defaultValue
            }
            return defaultValue
        }
        set {
            if let data = try? encoder.encode(newValue) {
#if os(macOS)
                userDefaults.setValue(data, forKey: key)
#else
                userDefaults.set(data, forKey: key)
#endif
            }
        }
    }

    private let key: String
    private let userDefaults: UserDefaults
    private var observerContext = 0
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaultValue: T
    private var onChangeHandler: ((T) -> Void)? = nil

    public init(wrappedValue defaultValue: T, _ key: String, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
        self.defaultValue = defaultValue
        super.init()

        if let data = try? encoder.encode(defaultValue) {
            DispatchQueue.main.async {
                userDefaults.register(defaults: [key: data])
            }
        }
#if os(macOS)
        // This fulfills requirement 4. Some implementations use NSUserDefaultsDidChangeNotification
        // but that is sent every time any value is updated in UserDefaults.
        userDefaults.addObserver(self, forKeyPath: key, options: .new, context: &observerContext)
#endif
    }

#if os(macOS)
    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?) {
            if context == &observerContext {
                onChangeHandler?(wrappedValue)
            } else {
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
#endif

    public func onChange(_ completion: @escaping (T) -> Void) {
        onChangeHandler = completion
    }

#if os(macOS)
    deinit {
        userDefaults.removeObserver(self, forKeyPath: key, context: &observerContext)
    }
#endif
}
