import Foundation
import XCTest
@preconcurrency import RevenueCat
@testable import IM_Iron_Splits

/// What the paywall says when a purchase does not go through.
final class PurchaseIssueTests: XCTestCase {
    /// Ask to Buy: RevenueCat's pending error reads as waiting, not failure.
    func testAskToBuyIsWaitingForApproval() {
        XCTAssertEqual(PurchaseIssue(RevenueCat.ErrorCode.paymentPendingError), .waitingForApproval)
        XCTAssertEqual(PurchaseIssue.waitingForApproval.message,
                       "Waiting for approval. Your purchase unlocks once it is approved.")
        XCTAssertFalse(PurchaseIssue.waitingForApproval.message.contains("Couldn't"))
    }

    /// RevenueCat hands errors back as an `NSError` in its own domain.
    func testBridgedPendingErrorIsWaitingForApproval() {
        let bridged = NSError(domain: RevenueCat.ErrorCode.errorDomain,
                              code: RevenueCat.ErrorCode.paymentPendingError.rawValue)
        XCTAssertEqual(PurchaseIssue(bridged), .waitingForApproval)
    }

    func testLostConnectionReadsAsTheStoreBeingUnreachable() {
        XCTAssertEqual(PurchaseIssue(RevenueCat.ErrorCode.networkError), .storeUnreachable)
        XCTAssertEqual(PurchaseIssue(RevenueCat.ErrorCode.offlineConnectionError), .storeUnreachable)
        XCTAssertEqual(PurchaseIssue(URLError(.notConnectedToInternet)), .storeUnreachable)
        XCTAssertEqual(PurchaseIssue.storeUnreachable.message,
                       "Couldn't reach the App Store. Check your connection and try again.")
    }

    func testOtherErrorsKeepTheGenericLine() {
        XCTAssertEqual(PurchaseIssue(RevenueCat.ErrorCode.purchaseNotAllowedError), .failed)
        XCTAssertEqual(PurchaseIssue(StoreServiceError.purchasesUnavailableInSimulator), .failed)
        XCTAssertEqual(PurchaseIssue.failed.message, "Couldn't complete the purchase. Please try again.")
    }
}
