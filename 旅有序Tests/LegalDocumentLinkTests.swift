import Foundation
import Testing
@testable import 旅有序

struct LegalDocumentLinkTests {
    @Test func eachLegalPageOpensItsMatchingGoogleDocument() {
        #expect(LegalKind.agreement.onlineURL.absoluteString == "https://docs.google.com/document/d/1MVV9jkBBT3WjM2Th-T13kz0nJBSSB3Psu0-HEK6VtV0/edit?tab=t.0")
        #expect(LegalKind.privacy.onlineURL.absoluteString == "https://docs.google.com/document/d/181JFFTIvkIHggjmweYQEvX2wfG9ZtgeyyM2stXeFNqg/edit?tab=t.0")
    }
}
