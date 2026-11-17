import Testing
import Foundation
@testable import 旅有序

struct WishStoreTests {
    @Test @MainActor func trimsPersistsAndRejectsEmptyOrOverlongWishes() {
        let suite = "WishStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = WishStore(defaults: defaults)
        #expect(!store.add("   "))
        #expect(store.add("  去海边看日落  "))
        #expect(store.wishes.first?.text == "去海边看日落")
        #expect(!store.add(String(repeating: "心", count: 81)))

        let reloaded = WishStore(defaults: defaults)
        #expect(reloaded.wishes.count == 1)
        reloaded.removeAll()
        #expect(WishStore(defaults: defaults).wishes.isEmpty)
    }
}
