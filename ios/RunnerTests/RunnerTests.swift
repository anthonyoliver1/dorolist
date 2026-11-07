import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  override func tearDown() {
    LiveActivityLinkRouter.pending = false
    LiveActivityLinkRouter.onOpenFocus = nil
    super.tearDown()
  }

  func testColdStartKeepsFocusLinkUntilFlutterIsReady() {
    LiveActivityLinkRouter.pending = false
    LiveActivityLinkRouter.onOpenFocus = nil
    XCTAssertTrue(LiveActivityLinkRouter.open(URL(string: "doro-list://focus")!))
    XCTAssertTrue(LiveActivityLinkRouter.pending)
  }

  func testWarmStartDeliversFocusLinkWithoutQueueingAnother() {
    LiveActivityLinkRouter.pending = false
    var opened = 0
    LiveActivityLinkRouter.onOpenFocus = { opened += 1 }
    XCTAssertTrue(LiveActivityLinkRouter.open(URL(string: "doro-list://focus")!))
    XCTAssertEqual(opened, 1)
    XCTAssertFalse(LiveActivityLinkRouter.pending)
    XCTAssertFalse(LiveActivityLinkRouter.open(URL(string: "https://example.com/focus")!))
    XCTAssertEqual(opened, 1)
  }
}
