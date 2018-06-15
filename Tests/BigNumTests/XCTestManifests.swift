import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BigNumTests.allTests),
        testCase(RationalTests.allTests),
        testCase(GenericMathTests.allTests),
    ]
}
#endif
