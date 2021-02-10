import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(MegicalEasyAccess_SDK_iOSTests.allTests),
    ]
}
#endif
