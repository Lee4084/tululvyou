import Foundation
import Combine

struct TravelWish: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
}

@MainActor
final class WishStore: ObservableObject {
    @Published private(set) var wishes: [TravelWish] = []
    @Published private(set) var message: String?
    private let defaults: UserDefaults
    private let key = "LvYouXu.wishes.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-personal") {
            defaults.removeObject(forKey: key)
        }
        #endif
        if let data = defaults.data(forKey: key) {
            do { wishes = try JSONDecoder().decode([TravelWish].self, from: data) }
            catch { message = "心愿暂时无法读取，请稍后重试。" }
        }
    }

    @discardableResult func add(_ input: String) -> Bool {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { message = "先写下一个心愿。"; return false }
        guard text.count <= 80 else { message = "心愿最多写 80 个字。"; return false }
        guard wishes.count < 50 else { message = "心愿墙最多保存 50 条。"; return false }
        return save([TravelWish(id: UUID(), text: text, createdAt: Date())] + wishes)
    }

    func remove(_ id: UUID) { _ = save(wishes.filter { $0.id != id }) }
    func removeAll() { _ = save([]) }

    @discardableResult private func save(_ next: [TravelWish]) -> Bool {
        do {
            defaults.set(try JSONEncoder().encode(next), forKey: key)
            wishes = next
            message = nil
            return true
        } catch {
            message = "心愿保存失败，请重试。"
            return false
        }
    }
}
