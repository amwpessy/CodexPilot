import XCTest
@testable import MacStatusCodexMonitor

final class FormattingTests: XCTestCase {
    func testByteFormatterUsesReadableUnits() {
        XCTAssertEqual(ByteFormatterUtility.string(bytes: 0), "0 B")
        XCTAssertEqual(ByteFormatterUtility.string(bytes: 1_536), "1.5 KB")
        XCTAssertEqual(ByteFormatterUtility.string(bytes: 1_073_741_824), "1 GB")
    }

    func testRateFormatterAddsPerSecond() {
        XCTAssertEqual(ByteFormatterUtility.rate(bytesPerSecond: 1_048_576), "1 MB/s")
    }

    func testSignedByteFormatterHandlesNegativeValues() {
        XCTAssertEqual(ByteFormatterUtility.signedString(bytes: -1_536), "-1.5 KB")
        XCTAssertEqual(
            ByteFormatterUtility.signedString(bytes: Int64.min),
            "-\(ByteFormatterUtility.string(bytes: Int64.min.magnitude))"
        )
    }

    func testPercentFormatterHandlesNil() {
        XCTAssertEqual(PercentFormatterUtility.string(nil), "Not reported")
        XCTAssertEqual(PercentFormatterUtility.string(42.4), "42%")
    }
}
