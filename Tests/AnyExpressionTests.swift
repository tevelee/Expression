//
//  ExpressionTests.swift
//  ExpressionTests
//
//  Created by Nick Lockwood on 18/04/2017.
//  Copyright © 2016 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Expression
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

@testable import Expression
import XCTest

private struct HashableStruct: Hashable {
    let foo: Int
    var hashValue: Int {
        return foo.hashValue
    }

    static func == (lhs: HashableStruct, rhs: HashableStruct) -> Bool {
        return lhs.foo == rhs.foo
    }
}

private struct EquatableStruct: Equatable {
    let foo: Int

    static func == (lhs: EquatableStruct, rhs: EquatableStruct) -> Bool {
        return lhs.foo == rhs.foo
    }
}

class AnyExpressionTests: XCTestCase {

    // MARK: Description

    func testDescriptionFormatting() {
        let expression = AnyExpression("a+b")
        XCTAssertEqual(expression.description, "a + b")
    }

    func testStringLiteralDescriptionNotMangled() {
        let expression = AnyExpression("foo('bar')")
        XCTAssertEqual(expression.description, "foo('bar')")
    }

    func testStringConstantDescriptionNotMangled() {
        let expression = AnyExpression("foo(bar)", constants: ["bar": "bar"])
        XCTAssertEqual(expression.description, "foo(bar)")
    }

    // MARK: Error description

    func testPrivateTypeErrorDescription() {
        let error = Expression.Error.typeMismatch(.infix("=="), [EquatableStruct(foo: 5), HashableStruct(foo: 6)])
        XCTAssert(error.description.contains("Arguments of type (EquatableStruct, HashableStruct) are not compatible with infix operator =="))
    }

    func testEquateNonHashableTypesErrorDescription() {
        let error = Expression.Error.typeMismatch(.infix("=="), [EquatableStruct(foo: 5), EquatableStruct(foo: 6)])
        XCTAssert(error.description.contains("Arguments for infix operator == must conform to the Hashable protocol"))
    }

    func testStringBoundsErrorDescription() {
        let error = Expression.Error.stringBounds("hello\nworld", "goodbye world".endIndex)
        XCTAssert(error.description.contains("Character index 13 out of bounds for string 'hello\\nworld'"))
    }

    // MARK: Arrays

    func testSubscriptArrayConstant() {
        let expression = AnyExpression("a[b]", constants: [
            "a": ["hello", "world"],
            "b": 1,
        ])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate() as String, "world")
    }

    func testSubscriptArraySliceConstant() {
        let expression = AnyExpression("a[b]", constants: [
            "a": ArraySlice(["hello", "world"]),
            "b": 1,
        ])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate() as String, "world")
    }

    func testArrayBounds() {
        let expression = AnyExpression("array[2]", constants: [
            "array": ["hello", "world"],
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.array("array"), 2))
        }
    }

    func testArraySliceBounds() {
        let expression = AnyExpression("array[2]", constants: [
            "array": ArraySlice(["hello", "world"]),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.array("array"), 2))
        }
    }

    func testSubscriptArrayWithString() {
        let expression = AnyExpression("a[b]", constants: [
            "a": ["hello", "world"],
            "b": "oops",
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.array("a"), ["oops"]))
        }
    }

    func testCompareEqualArrays() {
        let expression = AnyExpression("a == b", constants: [
            "a": ["hello", "world"],
            "b": ["hello", "world"],
        ])
        XCTAssertTrue(try expression.evaluate())
    }

    func testCompareUnequalArrays() {
        let expression = AnyExpression("a == b", constants: [
            "a": ["hello", "world"],
            "b": ["world", "hello"],
        ])
        XCTAssertFalse(try expression.evaluate())
    }

    func testCustomArraySymbol() {
        let expression = AnyExpression("a[100000000]", symbols: [
            .array("a"): { args in args[0] },
        ])
        XCTAssertEqual(try expression.evaluate(), 100000000)
    }

    func testArrayAccessOfIntConstant() {
        let expression = AnyExpression("foo[0]", constants: [
            "foo": 5,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .illegalSubscript(.array("foo"), 5))
        }
    }

    func testArrayAccessOfIntVariable() {
        let expression = AnyExpression("foo[0]", symbols: [
            .variable("foo"): { _ in 5 },
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .illegalSubscript(.array("foo"), 5))
        }
    }

    func testArrayAccessOfPureIntVariable() {
        let expression = AnyExpression(Expression.parse("foo[0]"), pureSymbols: { symbol in
            symbol == .variable("foo") ? { _ in 5 } : nil
        })
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .illegalSubscript(.array("foo"), 5))
        }
    }

    func testArrayAccessOfErrorThrowingVariable() {
        let expression = AnyExpression(Expression.parse("foo[0]"), pureSymbols: { symbol in
            symbol == .variable("foo") ? { _ in throw Expression.Error.message("Disabled") } : nil
        })
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .message("Disabled"))
        }
    }

    func testArrayAccessOfIntLiteral() {
        let expression = AnyExpression("5[1]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .illegalSubscript(.infix("[]"), 5.0))
        }
    }

    func testArrayAccessOfIntExpressionLiteral() {
        let expression = AnyExpression("(2 + 3)[1]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .illegalSubscript(.infix("[]"), 5.0))
        }
    }

    func testArrayAccessOfNonexistentSymbol() {
        let expression = AnyExpression("foo[0]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .undefinedSymbol(.array("foo")))
        }
    }

    func testStringArrayLiteral() {
        let expression = AnyExpression("['a','b','c']")
        XCTAssertEqual(try expression.evaluate(), ["a", "b", "c"])
    }

    func testDoubleArrayLiteral() {
        let expression = AnyExpression("[1.5, 2.5, 3.5]")
        XCTAssertEqual(try expression.evaluate(), [1.5, 2.5, 3.5])
    }

    func testIntArrayLiteral() {
        let expression = AnyExpression("[1,2,3]")
        XCTAssertEqual(try expression.evaluate(), [1, 2, 3])
    }

    func testIntArraySliceLiteral() {
        let expression = AnyExpression("[1,2,3]")
        XCTAssertEqual(try expression.evaluate(), ArraySlice([1, 2, 3]))
    }

    func testSubscriptIntArrayLiteral() {
        let expression = AnyExpression("[1,2,3][1]")
        XCTAssertEqual(try expression.evaluate(), 2)
    }

    func testSubscriptStringArrayLiteral() {
        let expression = AnyExpression("['a','b','c'][1]")
        XCTAssertEqual(try expression.evaluate(), "b")
    }

    func testSubscriptStringArrayLiteralWithString() {
        let expression = AnyExpression("['a','b','c']['foo']")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), [[Any](), "foo"]))
        }
    }

    func testSubscriptStringDictionaryWithInt() {
        let expression = AnyExpression("foo()[2]", symbols: [
            .function("foo", arity: 0): { _ in ["bar": "baz"] },
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), [[String: String](), 2.0]))
        }
    }

    func testSubscriptStringArrayLiteralOutOfBounds() {
        let expression = AnyExpression("['a','b','c'][3]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 3))
        }
    }

    func testConcatIntArrays() {
        let expression = AnyExpression("[1,2] + [3,4]")
        XCTAssertEqual(try expression.evaluate(), [1, 2, 3, 4])
    }

    func testConcatIntArraySlices() {
        let expression = AnyExpression("a + b", constants: [
            "a": ArraySlice([1, 2]),
            "b": ArraySlice([3, 4]),
        ])
        XCTAssertEqual(try expression.evaluate(), [1, 2, 3, 4])
    }

    func testConcatArrayAndArraySlice() {
        let expression = AnyExpression("a + [3, 4]", constants: [
            "a": ArraySlice([1, 2]),
        ])
        XCTAssertEqual(try expression.evaluate(), ArraySlice([1, 2, 3, 4]))
    }

    func testConcatMixedArrays() {
        let expression = AnyExpression("[1,2] + ['a', 'b']")
        XCTAssertEqual(try expression.evaluate() as [AnyHashable], [1.0, 2.0, "a", "b"])
    }

    // MARK: Dictionaries

    func testSubscriptStringDictionaryConstant() {
        let expression = AnyExpression("a[b]", constants: [
            "a": ["hello": "world"],
            "b": "hello",
        ])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate() as String, "world")
    }

    func testSubscriptDoubleDictionaryConstant() {
        let expression = AnyExpression("a[b]", constants: [
            "a": [1.0: "world"],
            "b": 1,
        ])
        XCTAssertEqual(try expression.evaluate(), "world")
    }

    func testSubscriptIntDictionaryConstantWithDouble() {
        let expression = AnyExpression("a[b]", constants: [
            "a": [1: "world"],
            "b": 1.0,
        ])
        XCTAssertEqual(try expression.evaluate(), "world")
    }

    func testSubscriptStringDictionaryConstantWithInt() {
        let expression = AnyExpression("a[b]", constants: [
            "a": ["hello": "world"],
            "b": 1,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.array("a"), [1.0]))
        }
    }

    func testSubscriptStringDictionaryConstantWithNonHashableType() {
        let expression = AnyExpression("a[b]", constants: [
            "a": ["hello": "world"],
            "b": EquatableStruct(foo: 1),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.array("a"), [EquatableStruct(foo: 1)]))
        }
    }

    func testUndefinedTupleSubscript() {
        let expression = AnyExpression("foo[(2,3)]", symbols: [
            .array("foo"): { _ in 0 },
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .unexpectedToken(","))
        }
    }

    func testTupleSubscript() {
        let expression = AnyExpression("foo[(2,3)]", symbols: [
            .variable("foo"): { _ in [5] },
            .infix(","): { $0 },
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.array("foo"), [[Any]()]))
        }
    }

    // MARK: Ranges

    func testClosedIntRange() {
        let expression = AnyExpression("1 ... 3")
        XCTAssertEqual(try expression.evaluate(), 1 ... 3)
    }

    func testHalfOpenIntRange() {
        let expression = AnyExpression("1 ..< 3")
        XCTAssertEqual(try expression.evaluate(), 1 ..< 3)
    }

    func testClosedStringIndexRange() {
        let string = "foo"
        let expression = AnyExpression("start ... end", constants: [
            "start": string.startIndex,
            "end": string.endIndex,
        ])
        XCTAssertEqual(try expression.evaluate(), string.startIndex ... string.endIndex)
    }

    func testHalfOpenStringIndexRange() {
        let string = "foo"
        let expression = AnyExpression("start ..< end", constants: [
            "start": string.startIndex,
            "end": string.endIndex,
        ])
        XCTAssertEqual(try expression.evaluate(), string.startIndex ..< string.endIndex)
    }

    func testInvalidTypeClosedRange() {
        let expression = AnyExpression("'a' ... 'b'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("..."), ["a", "b"]))
        }
    }

    func testMixedTypeClosedRange() {
        let expression = AnyExpression("1 ... index", constants: [
            "index": "foo".startIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("..."), [1.0, "foo".startIndex]))
        }
    }

    func testInvalidTypeHalfOpenRange() {
        let expression = AnyExpression("'a' ..< 'b'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("..<"), ["a", "b"]))
        }
    }

    func testMixedTypeHalfOpenRange() {
        let expression = AnyExpression("1 ..< index", constants: [
            "index": "foo".startIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("..<"), [1.0, "foo".startIndex]))
        }
    }

    func testInvalidClosedRange() {
        let expression = AnyExpression("1 ... -1")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .invalidRange(1, -1))
        }
    }

    func testInvalidClosedStringRange() {
        let range = "foo".startIndex ... "foo".endIndex
        let expression = AnyExpression("end ... start", constants: [
            "start": range.lowerBound,
            "end": range.upperBound,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .invalidRange(range.upperBound, range.lowerBound))
        }
    }

    func testInvalidHalfOpenRange() {
        let expression = AnyExpression("1 ..< 1")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .invalidRange(1, 1))
        }
    }

    func testInvalidHalfOpenStringRange() {
        let index = "foo".startIndex
        let expression = AnyExpression("start ..< start", constants: [
            "start": index,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .invalidRange(index, index))
        }
    }

    func testInvalidTypeRangeFrom() {
        let expression = AnyExpression("'a'...")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.postfix("..."), ["a"]))
        }
    }

    func testInvalidTypeRangeUpTo() {
        let expression = AnyExpression("..<'a'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.prefix("..<"), ["a"]))
        }
    }

    func testInvalidTypeRangeThrough() {
        let expression = AnyExpression("...'a'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.prefix("..."), ["a"]))
        }
    }

    // MARK: Array range subscripting

    func testSubscriptArrayWithCountableClosedRange() {
        let expression = AnyExpression("[1,2,3,4][1...2]")
        XCTAssertEqual(try expression.evaluate(), [2, 3])
    }

    func testSubscriptArrayWithClosedRange() {
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": ClosedRange(1 ... 2),
        ])
        XCTAssertEqual(try expression.evaluate(), [2, 3])
    }

    func testSubscriptArrayWithCountableHalfOpenRange() {
        let expression = AnyExpression("[1,2,3,4][1..<3]")
        XCTAssertEqual(try expression.evaluate(), [2, 3])
    }

    func testSubscriptArrayWithHalfOpenRange() {
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": Range(1 ..< 3),
        ])
        XCTAssertEqual(try expression.evaluate(), [2, 3])
    }

    func testSubscriptArrayWithRangeFrom() {
        let expression = AnyExpression("[1,2,3,4][1...]")
        XCTAssertEqual(try expression.evaluate(), [2, 3, 4])
    }

    func testSubscriptArrayWithRangeUpTo() {
        let expression = AnyExpression("[1,2,3,4][..<3]")
        XCTAssertEqual(try expression.evaluate(), [1, 2, 3])
    }

    func testSubscriptArrayWithRangeThrough() {
        let expression = AnyExpression("[1,2,3,4][...2]")
        XCTAssertEqual(try expression.evaluate(), [1, 2, 3])
    }

    func testSubscriptArrayWithWrongClosedRangeType() {
        let range = "foo".startIndex ... "foo".endIndex
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": range,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), [[Any](), range]))
        }
    }

    func testSubscriptArrayWithWrongHalfOpenRangeType() {
        let range = "foo".startIndex ..< "foo".endIndex
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": range,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), [[Any](), range]))
        }
    }

    func testSubscriptArrayWithWrongRangeFromType() {
        let range = "foo".endIndex...
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": range,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), [[Any](), range]))
        }
    }

    func testSubscriptArrayWithWrongRangeUpToType() {
        let range = ..<"foo".endIndex
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": range,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), [[Any](), range]))
        }
    }

    func testSubscriptArrayWithWrongRangeThroughType() {
        let range = ..."foo".endIndex
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": range,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), [[Any](), range]))
        }
    }

    func testSubscriptArrayWithCountableClosedLowerBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][-2...4]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), -2))
        }
    }

    func testSubscriptArrayWithClosedLowerBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": ClosedRange(-2 ... 4),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), -2))
        }
    }

    func testSubscriptArrayWithCountableHalfOpenLowerBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][-2..<4]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), -2))
        }
    }

    func testSubscriptArrayWithHalfOpenLowerBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": Range(-2 ..< 4),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), -2))
        }
    }

    func testSubscriptArrayWithCountableClosedUpperBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][3...4]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 4))
        }
    }

    func testSubscriptArrayWithClosedUpperBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": ClosedRange(1 ... 4),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 4))
        }
    }

    func testSubscriptArrayWithCountableHalfOpenUpperBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][3..<5]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 4))
        }
    }

    func testSubscriptArrayWithHalfOpenUpperBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][range]", constants: [
            "range": Range(1 ..< 5),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 4))
        }
    }

    func testSubscriptArrayWithRangeFromBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][4...]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 4))
        }
    }

    func testSubscriptArrayWithRangeFromBoundOutOfRange2() {
        let expression = AnyExpression("[1,2,3,4][-1...]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), -1))
        }
    }

    func testSubscriptArrayWithRangeUpToBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][..<5]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 4))
        }
    }

    func testSubscriptArrayWithRangeUpToBoundOutOfRange2() {
        let expression = AnyExpression("[1,2,3,4][..<0]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 0))
        }
    }

    func testSubscriptArrayWithRangeThroughBoundOutOfRange() {
        let expression = AnyExpression("[1,2,3,4][...4]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), 4))
        }
    }

    func testSubscriptArrayWithRangeThroughBoundOutOfRange2() {
        let expression = AnyExpression("[1,2,3,4][...-1]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arrayBounds(.infix("[]"), -1))
        }
    }

    // MARK: String subscripting

    func testSubscriptStringWithIndex() {
        let expression = AnyExpression("'foo'[index]", constants: [
            "index": "foo".startIndex,
        ])
        XCTAssertEqual(try expression.evaluate() as Character, "f")
    }

    func testSubscriptSubstringWithIndex() {
        let expression = AnyExpression("foo[index]", constants: [
            "foo": Substring("foo"),
            "index": "foo".startIndex,
        ])
        XCTAssertEqual(try expression.evaluate() as Character, "f")
    }

    func testSubscriptNSStringWithIndex() {
        let expression = AnyExpression("foo[index]", constants: [
            "foo": "foo" as NSString,
            "index": "foo".startIndex,
        ])
        XCTAssertEqual(try expression.evaluate() as Character, "f")
    }

    func testSubscriptStringWithOutOfRangeIndex() {
        let index = "food".endIndex
        let expression = AnyExpression("'foo'[index]", constants: [
            "index": index,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", index))
        }
    }

    func testSubscriptSubstringWithOutOfRangeIndex() {
        let index = "foobar".endIndex
        let expression = AnyExpression("foo[index]", constants: [
            "foo": Substring("foo"),
            "index": index,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", index))
        }
    }

    func testSubscriptNSStringWithOutOfRangeIndex() {
        let index = "foobarbaz".endIndex
        let expression = AnyExpression("foo[index]", constants: [
            "foo": "foo" as NSString,
            "index": index,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", index))
        }
    }

    func testSubscriptStringWithInt() {
        let expression = AnyExpression("'foo'[2]")
        XCTAssertEqual(try expression.evaluate() as Character, "o")
    }

    func testSubscriptSubstringWithInt() {
        let expression = AnyExpression("foo[2]", constants: [
            "foo": Substring("foo"),
        ])
        XCTAssertEqual(try expression.evaluate() as Character, "o")
    }

    func testSubscriptNSStringWithInt() {
        let expression = AnyExpression("foo[2]", constants: [
            "foo": "foo" as NSString,
        ])
        XCTAssertEqual(try expression.evaluate() as Character, "o")
    }

    func testSubscriptStringWithOutOfRangeInt() {
        let expression = AnyExpression("'foo'[5]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 5))
        }
    }

    func testSubscriptSubstringWithOutOfRangeInt() {
        let expression = AnyExpression("foo[4]", constants: [
            "foo": Substring("foo"),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 4))
        }
    }

    func testSubscriptNSStringWithOutOfRangeInt() {
        let expression = AnyExpression("foo[9]", constants: [
            "foo": "foo" as NSString,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 9))
        }
    }

    func testSubscriptStringLiteralWithInvalidIndexType() {
        let expression = AnyExpression("'foo'[index]", constants: [
            "index": NSObject(),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.array("'foo'"), [NSObject()]))
        }
    }

    func testSubscriptStringExpressionWithInvalidIndexType() {
        let expression = AnyExpression("('foo' + 'bar')[index]", constants: [
            "index": NSObject(),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("[]"), ["foobar", NSObject()]))
        }
    }

    func testSubscriptStringWithHalfOpenIndexRange() {
        let expression = AnyExpression("'foo'[range]", constants: [
            "range": "foo".range(of: "fo")!,
        ])
        XCTAssertEqual(try expression.evaluate(), "fo")
    }

    func testSubscriptStringWithClosedIndexRange() {
        let expression = AnyExpression("'foo'[range]", constants: [
            "range": "foo".startIndex ... "foo".index(after: "foo".startIndex),
        ])
        XCTAssertEqual(try expression.evaluate(), "fo")
    }

    func testSubscriptSubstringWithHalfOpenIndexRange() {
        let expression = AnyExpression("foo[range]", constants: [
            "foo": Substring("foo"),
            "range": "foo".range(of: "fo")!,
        ])
        XCTAssertEqual(try expression.evaluate(), "fo")
    }

    func testSubscriptNSStringWithHalfOpenIndexRange() {
        let expression = AnyExpression("foo[range]", constants: [
            "foo": "foo" as NSString,
            "range": "foo".range(of: "fo")!,
        ])
        XCTAssertEqual(try expression.evaluate(), "fo")
    }

    func testSubscriptStringWithInvalidHalfOpenIndexRange() {
        let expression = AnyExpression("'foo'[range]", constants: [
            "range": "foobar".range(of: "bar")!,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptStringWithInvalidClosedIndexRange() {
        let expression = AnyExpression("'foo'[range]", constants: [
            "range": "foobar".range(of: "bar")!.lowerBound ... "foobar".endIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptSubstringWithInvalidHalfOpenIndexRange() {
        let expression = AnyExpression("foo[range]", constants: [
            "foo": "barfoo".suffix(3),
            "range": "barfoo".range(of: "bar")!,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", -3))
        }
    }

    func testSubscriptNSStringWithInvalidHalfOpenIndexRangeLowerBound() {
        let expression = AnyExpression("foo[range]", constants: [
            "foo": "foo" as NSString,
            "range": "foobarbaz".range(of: "baz")!,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 6))
        }
    }

    func testSubscriptNSStringWithInvalidHalfOpenIndexRangeUpperBound() {
        let expression = AnyExpression("foo[range]", constants: [
            "foo": "foo" as NSString,
            "range": "foobar".range(of: "obar")!,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 6))
        }
    }

    func testSubscriptNSStringWithInvalidClosedIndexRangeLowerBound() {
        let expression = AnyExpression("foo[range]", constants: [
            "foo": "foo" as NSString,
            "range": "foobarbaz".range(of: "baz")!.lowerBound ... "foobarbaz".endIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 6))
        }
    }

    func testSubscriptNSStringWithInvalidClosedIndexRangeUpperBound() {
        let expression = AnyExpression("foo[range]", constants: [
            "foo": "foo" as NSString,
            "range": "foobar".range(of: "obar")!.lowerBound ... "foobar".endIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 6))
        }
    }

    func testSubscriptStringWithIntRange() {
        let expression = AnyExpression("'foo'[1..<3]")
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptSubstringWithIntRange() {
        let expression = AnyExpression("foo[1..<3]", constants: [
            "foo": Substring("foo"),
        ])
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptNSStringWithIntRange() {
        let expression = AnyExpression("foo[1..<3]", constants: [
            "foo": "foo" as NSString,
        ])
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptStringWithClosedIntRange() {
        let expression = AnyExpression("'foo'[1...2]")
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptSubstringWithClosedIntRange() {
        let expression = AnyExpression("foo[1...2]", constants: [
            "foo": Substring("foo"),
        ])
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptNSStringWithClosedIntRange() {
        let expression = AnyExpression("foo[1...2]", constants: [
            "foo": "foo" as NSString,
        ])
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptNSStringWithInvalidClosedIntRangeLowerBound() {
        let expression = AnyExpression("foo[-1...2]", constants: [
            "foo": "foo" as NSString,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", -1))
        }
    }

    func testSubscriptNSStringWithInvalidClosedIntRangeUpperBound() {
        let expression = AnyExpression("foo[1...3]", constants: [
            "foo": "foo" as NSString,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptStringFromIntRange() {
        let expression = AnyExpression("'foo'[1...]")
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptStringFromInvalidIntRange() {
        let expression = AnyExpression("'foo'[-1...]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", -1))
        }
    }

    func testSubscriptStringFromInvalidIntRange2() {
        let expression = AnyExpression("'foo'[3...]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptStringUpToIntRange() {
        let expression = AnyExpression("'foo'[..<2]")
        XCTAssertEqual(try expression.evaluate(), "fo")
    }

    func testSubscriptStringUpToInvalidIntRange() {
        let expression = AnyExpression("'foo'[..<4]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptStringUpToInvalidIntRange2() {
        let expression = AnyExpression("'foo'[..<0]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 0))
        }
    }

    func testSubscriptStringThroughIntRange() {
        let expression = AnyExpression("'foo'[...2]")
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testSubscriptStringThroughIntRangeEdgeCase() {
        let expression = AnyExpression("'foo'[...0]")
        XCTAssertEqual(try expression.evaluate(), "f")
    }

    func testSubscriptStringThroughInvalidIntRange() {
        let expression = AnyExpression("'foo'[...3]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptStringThroughInvalidIntRange2() {
        let expression = AnyExpression("'foo'[...-1]")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", -1))
        }
    }

    func testSubscriptStringFromIndexRange() {
        let expression = AnyExpression("'foo'[index...]", constants: [
            "index": "foo".index(of: "o")!,
        ])
        XCTAssertEqual(try expression.evaluate(), "oo")
    }

    func testSubscriptStringFromInvalidIndexRange() {
        let expression = AnyExpression("'foo'[index...]", constants: [
            "index": "food".index(of: "d")!,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptStringFromInvalidIndexRange2() {
        let expression = AnyExpression("foo[index...]", constants: [
            "foo": "afoo"["afoo".range(of: "foo")!],
            "index": "afoo".startIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", -1))
        }
    }

    func testSubscriptStringUpToIndexRange() {
        let expression = AnyExpression("'foo'[..<index]", constants: [
            "index": "foo".index(before: "foo".endIndex),
        ])
        XCTAssertEqual(try expression.evaluate(), "fo")
    }

    func testSubscriptStringUpToInvalidIndexRange() {
        let expression = AnyExpression("'foo'[..<index]", constants: [
            "index": "food".index(after: "foo".endIndex),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 4))
        }
    }

    func testSubscriptStringUpToInvalidIndexRange2() {
        let expression = AnyExpression("'foo'[..<index]", constants: [
            "index": "foo".startIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 0))
        }
    }

    func testSubscriptStringThroughIndexRange() {
        let expression = AnyExpression("'foo'[...index]", constants: [
            "index": "food".index(before: "foo".endIndex),
        ])
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testSubscriptStringThroughIndexRangeEdgeCase() {
        let expression = AnyExpression("'foo'[...index]", constants: [
            "index": "food".startIndex,
        ])
        XCTAssertEqual(try expression.evaluate(), "f")
    }

    func testSubscriptStringThroughInvalidIndexRange() {
        let expression = AnyExpression("'foo'[...index]", constants: [
            "index": "foo".endIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", 3))
        }
    }

    func testSubscriptStringThroughInvalidIndexRange2() {
        let expression = AnyExpression("foo[...index]", constants: [
            "foo": "afoo"["afoo".range(of: "foo")!],
            "index": "afoo".startIndex,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .stringBounds("foo", -1))
        }
    }

    // MARK: Numeric types

    func testAddNumbers() {
        let expression = AnyExpression("4 + 5")
        XCTAssertEqual(try expression.evaluate(), 9)
    }

    func testMathConstants() {
        let expression = AnyExpression("pi")
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate(), Double.pi)
    }

    func testAddNumericConstants() {
        let expression = AnyExpression("a + b", constants: [
            "a": UInt64(4),
            "b": 5,
        ])
        XCTAssertEqual(try expression.evaluate(), 9)
    }

    func testPreserveNumericPrecision() {
        let expression = AnyExpression("true ? a : b", constants: [
            "a": UInt64.max,
            "b": Int64.min,
        ])
        XCTAssertEqual(try expression.evaluate(), UInt64.max)
    }

    func testAddVeryLargeNumericConstants() {
        let expression = AnyExpression("a + b", constants: [
            "a": Int64.max,
            "b": Int64.max,
        ])
        XCTAssertEqual(try expression.evaluate(), Double(Int64.max) + Double(Int64.max))
    }

    func testNaN() {
        let expression = AnyExpression("NaN + 5", constants: ["NaN": Double.nan])
        XCTAssertEqual((try expression.evaluate() as Double).isNaN, true)
    }

    func testEvilEdgeCase() {
        let evilValue = (-Double.nan) // exactly matches mask
        let expression = AnyExpression("evil + 5", constants: ["evil": evilValue])
        XCTAssertEqual((try expression.evaluate() as Double).bitPattern, evilValue.bitPattern)
    }

    func testEvilEdgeCase2() {
        let evilValue = Double(bitPattern: (-Double.nan).bitPattern + 1 + 4) // outside range of stored variables
        let expression = AnyExpression("evil + 5", constants: ["evil": evilValue])
        XCTAssertEqual((try expression.evaluate() as Double).bitPattern, (evilValue + 5).bitPattern)
    }

    func testEvilEdgeCase3() {
        let evilValue = Double(bitPattern: (-Double.nan).bitPattern - 1) // outside range of stored variables
        let expression = AnyExpression("evil + 5", constants: ["evil": evilValue])
        XCTAssertEqual((try expression.evaluate() as Double).bitPattern, (evilValue + 5).bitPattern)
    }

    func testFloatNaN() {
        let expression = AnyExpression("NaN + 5", constants: ["NaN": Float.nan])
        XCTAssertEqual((try expression.evaluate() as Double).isNaN, true)
    }

    func testInfinity() {
        let expression = AnyExpression("1/0")
        XCTAssertEqual((try expression.evaluate() as Double).isInfinite, true)
    }

    func testCGFloatTreatedAsDouble() throws {
        let expression = AnyExpression("foo + 5", constants: ["foo": CGFloat(5)])
        let result: Any = try expression.evaluate()
        XCTAssertEqual("\(type(of: result))", "Double")
        XCTAssertEqual(result as? Double, 10)
    }

    #if swift(>=4)

        func testFontWeightTypePreserved() throws {
            let expression = AnyExpression("foo", constants: ["foo": NSFont.Weight(5)])
            let result: Any = try expression.evaluate()
            XCTAssertEqual("\(type(of: result))", "Weight")
        }

    #endif

    // MARK: String concatenation

    func testAddStringConstants() {
        let expression = AnyExpression("a + b", constants: [
            "a": "foo",
            "b": "bar",
        ])
        XCTAssertEqual(try expression.evaluate(), "foobar")
    }

    func testAddNumericConstantsWithString() {
        let expression = AnyExpression("a + b == 9 ? c : ''", constants: [
            "a": 4,
            "b": 5,
            "c": "foo",
        ])
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testAddStringLiterals() {
        let expression = AnyExpression("'foo' + 'bar'")
        XCTAssertEqual(try expression.evaluate(), "foobar")
    }

    func testAddNumberToString() {
        let expression = AnyExpression("5 + 'foo'")
        XCTAssertEqual(try expression.evaluate(), "5foo")
    }

    func testAddStringToInt() {
        let expression = AnyExpression("'foo' + 5")
        XCTAssertEqual(try expression.evaluate(), "foo5")
    }

    func testAddStringToBigInt() {
        let expression = AnyExpression("'foo' + bar", constants: ["bar": UInt64.max])
        XCTAssertEqual(try expression.evaluate(), "foo\(UInt64.max)")
    }

    func testAddStringToDouble() {
        let expression = AnyExpression("'foo' + 5.1")
        XCTAssertEqual(try expression.evaluate(), "foo5.1")
    }

    func testAddStringToFalse() {
        let expression = AnyExpression("'foo' + false")
        XCTAssertEqual(try expression.evaluate(), "foofalse")
    }

    func testAddStringToTrue() {
        let expression = AnyExpression("'foo' + true")
        XCTAssertEqual(try expression.evaluate(), "footrue")
    }

    func testAddStringVariables() {
        let expression = AnyExpression("a + b", symbols: [
            .variable("a"): { _ in "foo" },
            .variable("b"): { _ in "bar" },
        ])
        XCTAssertEqual(expression.symbols, [.variable("a"), .variable("b"), .infix("+")])
        XCTAssertEqual(try expression.evaluate(), "foobar")
    }

    func testAddMixedConstantsAndVariables() {
        let expression = AnyExpression(
            "a + b + c",
            constants: [
                "a": "foo",
                "b": "bar",
            ],
            symbols: [
                .variable("c"): { _ in "baz" },
            ]
        )
        XCTAssertEqual(expression.symbols, [.variable("c"), .infix("+")])
        XCTAssertEqual(try expression.evaluate(), "foobarbaz")
    }

    // MARK: Boolean logic

    func testMixedConstantsAndVariables() {
        let expression = AnyExpression(
            "foo ? #F00 : #00F",
            constants: [
                "#F00": "red",
                "#00F": "blue",
            ],
            symbols: [
                .variable("foo"): { _ in false },
            ]
        )
        XCTAssertEqual(expression.symbols, [.variable("foo"), .infix("?:")])
        XCTAssertEqual(try expression.evaluate(), "blue")
    }

    func testEquateStrings() {
        let constants: [String: Any] = [
            "a": "foo",
            "b": "bar",
            "c": "bar",
        ]
        let expression1 = AnyExpression("a == b", constants: constants)
        XCTAssertFalse(try expression1.evaluate())
        let expression2 = AnyExpression("a != b", constants: constants)
        XCTAssertTrue(try expression2.evaluate())
        let expression3 = AnyExpression("b == c", constants: constants)
        XCTAssertTrue(try expression3.evaluate())
        let expression4 = AnyExpression("b != c", constants: constants)
        XCTAssertFalse(try expression4.evaluate())
    }

    func testEquateNSObjects() {
        let object1 = NSObject()
        let object2 = NSObject()
        let constants: [String: Any] = [
            "a": object1,
            "b": object2,
            "c": object2,
        ]
        let expression1 = AnyExpression("a == b", constants: constants)
        XCTAssertFalse(try expression1.evaluate())
        let expression2 = AnyExpression("a != b", constants: constants)
        XCTAssertTrue(try expression2.evaluate())
        let expression3 = AnyExpression("b == c", constants: constants)
        XCTAssertTrue(try expression3.evaluate())
    }

    func testEquateArrays() {
        let constants: [String: Any] = [
            "a": ["hello", "world"],
            "b": ["goodbye", "world"],
            "c": ["goodbye", "world"],
        ]
        let expression1 = AnyExpression("a == b", constants: constants)
        XCTAssertFalse(try expression1.evaluate())
        let expression2 = AnyExpression("a != b", constants: constants)
        XCTAssertTrue(try expression2.evaluate())
        let expression3 = AnyExpression("b == c", constants: constants)
        XCTAssertTrue(try expression3.evaluate())
    }

    func testEquateDictionaries() {
        let constants: [String: Any] = [
            "a": ["hello": "world"],
            "b": ["goodbye": "world"],
            "c": ["goodbye": "world"],
        ]
        let expression1 = AnyExpression("a == b", constants: constants)
        XCTAssertFalse(try expression1.evaluate())
        let expression2 = AnyExpression("a != b", constants: constants)
        XCTAssertTrue(try expression2.evaluate())
        let expression3 = AnyExpression("b == c", constants: constants)
        XCTAssertTrue(try expression3.evaluate())
    }

    func testEquateHashableStructs() {
        let a = HashableStruct(foo: 4)
        let b = HashableStruct(foo: 5)
        let c = HashableStruct(foo: 5)
        let constants: [String: Any] = [
            "a": a,
            "b": b,
            "c": c,
        ]
        let expression1 = AnyExpression("a == b", constants: constants)
        XCTAssertFalse(try expression1.evaluate())
        let expression2 = AnyExpression("a != b", constants: constants)
        XCTAssertTrue(try expression2.evaluate())
        let expression3 = AnyExpression("b == c", constants: constants)
        XCTAssertTrue(try expression3.evaluate())
    }

    func testEquateTuples() {
        let tuples: [Any] = [
            (1, 2),
            (1, 2, 3),
            (1, 2, 3, 4),
            (1, 2, 3, 4, 5),
            (1, 2, 3, 4, 5, 6),
        ]
        for tuple in tuples {
            let expression1 = AnyExpression("a == b", constants: [
                "a": tuple, "b": tuple,
            ])
            XCTAssertTrue(try expression1.evaluate())
            let expression2 = AnyExpression("a == b", constants: [
                "a": tuple, "b": (1, 3),
            ])
            do {
                let result: Bool = try expression2.evaluate()
                XCTAssertFalse(result)
            } catch let error as Expression.Error {
                XCTAssertEqual(error, .typeMismatch(.infix("=="), [tuple, (1, 3)]))
            } catch {
                XCTFail()
            }
        }
    }

    func testGreaterThanWithLargeIntegers() {
        let expression = AnyExpression("a > b", constants: [
            "a": Int64.max,
            "b": Int64.max - 1000,
        ])
        XCTAssertTrue(try expression.evaluate())
    }

    func testLessThanEqualWithLargeIntegers() {
        let expression = AnyExpression("a <= b", constants: [
            "a": Int64.max,
            "b": Int64.max - 1000,
        ])
        XCTAssertFalse(try expression.evaluate())
    }

    func testAndOperatorReturnsBool() {
        let expression = AnyExpression("a && b", constants: [
            "a": true,
            "b": true,
        ])
        XCTAssertTrue(try expression.evaluate())
    }

    func testOrOperatorReturnsBool() {
        let expression = AnyExpression("a || b", constants: [
            "a": false,
            "b": false,
        ])
        XCTAssertFalse(try expression.evaluate())
    }

    func testNotNaNEqualsNan() {
        let expression = AnyExpression("NaN == NaN", constants: [
            "NaN": Double.nan,
        ])
        XCTAssertFalse(try expression.evaluate())
    }

    func testNaNNotEqualToNan() {
        let expression = AnyExpression("NaN != NaN", constants: [
            "NaN": Double.nan,
        ])
        XCTAssertTrue(try expression.evaluate())
    }

    func testNotFloatNaNEqualsNan() {
        let expression = AnyExpression("NaN == NaN", constants: [
            "NaN": Float.nan,
        ])
        XCTAssertFalse(try expression.evaluate())
    }

    func testEqualsOperatorWhenBooleansDisabled() {
        let expression = AnyExpression("5 == 6", options: [])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .undefinedSymbol(.infix("==")))
        }
    }

    func testCustomEqualsOperatorWhenBooleansDisabled() {
        let expression = AnyExpression("5 == 6", options: [], symbols: [
            .infix("=="): { _ in true },
        ])
        XCTAssertTrue(try expression.evaluate())
    }

    func testCustomEqualsOperatorWhenBooleansEnabled() {
        let expression = AnyExpression("5 == 6", symbols: [
            .infix("=="): { _ in true },
        ])
        XCTAssertTrue(try expression.evaluate())
    }

    // MARK: Optionals

    func testNilString() {
        let null: String? = nil
        let expression = AnyExpression("foo + 'bar'", constants: ["foo": null as Any])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("+"), [nil as Any? as Any, "bar"]))
        }
    }

    func testNilString2() {
        let null: String? = nil
        let expression1 = AnyExpression("foo == nil ? 'bar' : 'foo'", constants: ["foo": null as Any])
        XCTAssertEqual(try expression1.evaluate(), "bar")
        let expression2 = AnyExpression("foo == nil ? 'bar' : 'foo'", constants: ["foo": "notnull"])
        XCTAssertEqual(try expression2.evaluate(), "foo")
    }

    func testIOUNilString() {
        let null: String! = nil
        let expression = AnyExpression("foo + 'bar'", constants: ["foo": null as Any])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("+"), [NSNull(), "bar"]))
        }
    }

    func testOptionalOptionalNilString() {
        let null: Optional<Optional<String>> = nil
        let expression = AnyExpression("foo + 'bar'", constants: ["foo": null as Any])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("+"), [nil as Any? as Any, "bar"]))
        }
    }

    func testOptionalOptionalNonnilString() {
        let foo: Optional<Optional<String>> = "foo"
        let expression = AnyExpression("foo + 'bar'", constants: ["foo": foo as Any])
        XCTAssertEqual(try expression.evaluate(), "foobar")
    }

    func testNullCoalescing() {
        let null: String? = nil
        let expression = AnyExpression("foo ?? 'bar'", constants: ["foo": null as Any])
        XCTAssertEqual(try expression.evaluate(), "bar")
    }

    func testNullCoalescing2() {
        let foo: String? = "foo"
        let expression = AnyExpression("foo ?? 'bar'", constants: ["foo": foo as Any])
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testIUONullCoalescing() {
        let null: String! = nil
        let expression = AnyExpression("foo ?? 'bar'", constants: ["foo": null as Any])
        XCTAssertEqual(try expression.evaluate(), "bar")
    }

    func testIUONullCoalescing2() {
        let foo: String! = "foo"
        let expression = AnyExpression("foo ?? 'bar'", constants: ["foo": foo as Any])
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testNSNullCoalescing() {
        let expression = AnyExpression("foo ?? 'bar'", constants: ["foo": NSNull()])
        XCTAssertEqual(try expression.evaluate(), "bar")
    }

    func testNonNullCoalescing() {
        let expression = AnyExpression("foo ?? 'bar'", constants: ["foo": "foo"])
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testNullEqualsString() {
        let null: String? = nil
        let expression = AnyExpression("foo == 'bar'", constants: ["foo": null as Any])
        XCTAssertFalse(try expression.evaluate())
    }

    func testOptionalStringEqualsString() {
        let null: String? = "bar"
        let expression = AnyExpression("foo == 'bar'", constants: ["foo": null as Any])
        XCTAssertTrue(try expression.evaluate())
    }

    func testNullEqualsDouble() {
        let null: Double? = nil
        let expression = AnyExpression("foo == 5.5", constants: ["foo": null as Any])
        XCTAssertFalse(try expression.evaluate())
    }

    func testOptionalDoubleEqualsDouble() {
        let null: Double? = 5.5
        let expression = AnyExpression("foo == 5.5", constants: ["foo": null as Any])
        XCTAssertTrue(try expression.evaluate())
    }

    func testEvaluateNilAsString() {
        let expression = AnyExpression("nil")
        XCTAssertThrowsError(try expression.evaluate() as String) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch(String.self, nil as Any? as Any))
        }
    }

    func testEvaluateNilAsOptionalString() {
        let expression = AnyExpression("nil")
        XCTAssertNil(try expression.evaluate() as String?)
    }

    // MARK: Errors

    func testUnknownOperator() {
        let expression = AnyExpression("'foo' %% 'bar'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .undefinedSymbol(.infix("%%")))
        }
    }

    func testUnknownVariable() {
        let expression = AnyExpression("foo")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .undefinedSymbol(.variable("foo")))
        }
    }

    func testBinaryTernary() {
        let expression = AnyExpression("'foo' ?: 'bar'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .undefinedSymbol(.infix("?:")))
        }
    }

    func testTernaryWithNonBooleanArgument() {
        let expression = AnyExpression("'foo' ? 1 : 2")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("?:"), ["foo", 1.0, 2.0]))
        }
    }

    func testNotOperatorWithNonBooleanArgument() {
        let expression = AnyExpression("!'foo'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.prefix("!"), ["foo"]))
        }
    }

    func testAddDates() {
        let expression = AnyExpression("a + b", constants: [
            "a": Date(),
            "b": Date(),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("+"), [Date(), Date()]))
        }
    }

    func testCompareObjects() {
        let expression = AnyExpression("a > b", constants: [
            "a": NSObject(),
            "b": NSObject(),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix(">"), [NSObject(), NSObject()]))
        }
    }

    func testAddStringAndNil() {
        let expression = AnyExpression("a + b", constants: [
            "a": "foo",
            "b": nil as Any? as Any,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("+"), ["foo", nil as Any? as Any]))
        }
    }

    func testAddStringAndNSNull() {
        let expression = AnyExpression("a + b", constants: [
            "a": "foo",
            "b": NSNull(),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("+"), ["foo", NSNull()]))
        }
    }

    func testAddIntAndNil() {
        let expression = AnyExpression("a + b", constants: [
            "a": 5,
            "b": nil as Any? as Any,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("+"), [5.0, nil as Any? as Any]))
        }
    }

    func testMultiplyIntAndNil() {
        let expression = AnyExpression("a * b", constants: [
            "a": 5,
            "b": nil as Any? as Any,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("*"), [5.0, nil as Any? as Any]))
        }
    }

    func testAndBoolAndNil() {
        let expression = AnyExpression("a && b", constants: [
            "a": true,
            "b": nil as Any? as Any,
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("&&"), [true, nil as Any? as Any]))
        }
    }

    func testTypeMismatch() {
        let expression = AnyExpression("5 / 'foo'")
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("/"), [5.0, "foo"]))
        }
    }

    func testCastStringAsDouble() {
        let expression = AnyExpression("'foo' + 'bar'")
        XCTAssertThrowsError(try expression.evaluate() as Double) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch(Double.self, "foobar"))
        }
    }

    func testCastDoubleAsDate() {
        let expression = AnyExpression("5.6")
        XCTAssertThrowsError(try expression.evaluate() as NSDate) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch(NSDate.self, 5.6))
        }
    }

    func testCastNilAsDouble() {
        let expression = AnyExpression("nil")
        XCTAssertThrowsError(try expression.evaluate() as Double) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch(Double.self, nil as Any? as Any))
        }
    }

    func testCastDoubleAsStruct() {
        let expression = AnyExpression("5")
        XCTAssertThrowsError(try expression.evaluate() as HashableStruct) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch(HashableStruct.self, 5.0))
        }
    }

    func testCastNSNullAsDouble() {
        let expression = AnyExpression("null", constants: ["null": NSNull()])
        XCTAssertThrowsError(try expression.evaluate() as Double) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch(Double.self, NSNull()))
        }
    }

    func testCastStringAsArray() {
        let expression = AnyExpression("'foo'")
        XCTAssertThrowsError(try expression.evaluate() as [Any]) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch([Any].self, "foo"))
        }
    }

    func testCastStringArrayAsIntArray() {
        let expression = AnyExpression("['foo']")
        XCTAssertThrowsError(try expression.evaluate() as [Int]) { error in
            XCTAssertEqual(error as? Expression.Error, .resultTypeMismatch([Int].self, [Any]()))
        }
    }

    func testDisableNullCoalescing() {
        let expression = AnyExpression("nil ?? 'foo'", symbols: [
            .infix("??"): { _ in throw AnyExpression.Error.message("Disabled") },
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .message("Disabled"))
        }
    }

    func testDisableVariableSymbol() {
        let expression = AnyExpression(
            Expression.parse("foo + pi"),
            pureSymbols: { symbol in
                if case .variable("foo") = symbol {
                    return { _ in throw AnyExpression.Error.message("Disabled") }
                }
                return nil
            }
        )
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .message("Disabled"))
        }
    }

    func testDisableVariableSymbol2() {
        let expression = AnyExpression(
            Expression.parse("foo + pi"),
            impureSymbols: { symbol in
                if case .variable("foo") = symbol {
                    return { _ in throw AnyExpression.Error.message("Disabled") }
                }
                return nil
            }
        )
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .message("Disabled"))
        }
    }

    func testCompareStringAndArray() {
        let expression = AnyExpression("a == b", constants: [
            "a": ["world", "hello"],
            "b": "hello world",
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .typeMismatch(.infix("=="), [["a"], "b"]))
        }
    }

    func testCompareEquatableStructs() {
        let expression = AnyExpression("a == b", constants: [
            "a": EquatableStruct(foo: 1),
            "b": EquatableStruct(foo: 1),
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssert("\(error)".contains("Hashable"))
        }
    }

    func testTooFewArguments() {
        let expression = AnyExpression("pow(4)")
        XCTAssertThrowsError(try expression.evaluate() as Double) { error in
            XCTAssertEqual(error as? Expression.Error, .arityMismatch(.function("pow", arity: 2)))
        }
    }

    func testTooFewArgumentsForCustomFunction() {
        let expression = AnyExpression("foo(4)", symbols: [
            .function("foo", arity: 2): { $0 },
        ])
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arityMismatch(.function("foo", arity: 2)))
        }
    }

    func testTooFewArgumentsWithAdvancedInitializer() {
        let expression = AnyExpression(Expression.parse("pow(4)"), pureSymbols: { _ in nil })
        XCTAssertThrowsError(try expression.evaluate() as Double) { error in
            XCTAssertEqual(error as? Expression.Error, .arityMismatch(.function("pow", arity: 2)))
        }
    }

    func testTooFewArgumentsForCustomFunctionWithAdvancedInitializer() {
        let expression = AnyExpression(Expression.parse("foo(4)"), pureSymbols: { symbol in
            switch symbol {
            case .function("foo", arity: 2):
                return { $0 }
            default:
                return nil
            }
        })
        XCTAssertThrowsError(try expression.evaluate() as Any) { error in
            XCTAssertEqual(error as? Expression.Error, .arityMismatch(.function("foo", arity: 2)))
        }
    }

    func testTooManyArguments() {
        let expression = AnyExpression("pow(4,5,6)")
        XCTAssertThrowsError(try expression.evaluate() as Double) { error in
            XCTAssertEqual(error as? Expression.Error, .arityMismatch(.function("pow", arity: 2)))
        }
    }

    // MARK: Return type casting

    func testCastBoolResultAsDouble() {
        let expression = AnyExpression("5 > 4")
        XCTAssertEqual(try expression.evaluate(), 1.0)
    }

    func testCastDoubleResultAsInt() {
        let expression = AnyExpression("57.5")
        XCTAssertEqual(try expression.evaluate(), 57)
    }

    func testCastDoubleResultAsInt8() {
        let expression = AnyExpression("57.5")
        XCTAssertEqual(try expression.evaluate() as Int8, 57)
    }

    func testCastDoubleResultAsOptionalInt8() {
        let expression = AnyExpression("57.5")
        XCTAssertEqual(try expression.evaluate() as Int8?, 57)
    }

    func testCastNonzeroResultAsBool() {
        let expression = AnyExpression("0.6")
        XCTAssertEqual(try expression.evaluate(), true)
    }

    func testCastZeroResultAsBool() {
        let expression = AnyExpression("0")
        XCTAssertEqual(try expression.evaluate(), false)
    }

    func testCastZeroResultAsOptionalBool() {
        let expression = AnyExpression("0")
        XCTAssertEqual(try expression.evaluate() as Bool?, false)
    }

    func testCastDoubleAsString() {
        let expression = AnyExpression("5.6")
        XCTAssertEqual(try expression.evaluate(), "5.6")
    }

    func testCastDoubleAsSubstring() {
        let expression = AnyExpression("5.6")
        XCTAssertEqual(try expression.evaluate(), Substring("5.6"))
    }

    func testCastDoubleAsOptionalString() {
        let expression = AnyExpression("5.6")
        XCTAssertEqual(try expression.evaluate() as String?, "5.6")
    }

    func testCastDoubleAsOptionalSubstring() {
        let expression = AnyExpression("5.6")
        XCTAssertEqual(try expression.evaluate() as Substring?, "5.6")
    }

    func testCastDoubleResultAsOptionalDouble() {
        let expression = AnyExpression("5 + 4")
        XCTAssertEqual(try expression.evaluate() as Double?, 9)
    }

    func testCastInt8ResultAsDouble() {
        let expression = AnyExpression("foo", constants: ["foo": Int8(5)])
        XCTAssertEqual(try expression.evaluate() as Double, 5)
    }

    func testCastNilResultAsOptionalDouble() {
        let expression = AnyExpression("nil")
        XCTAssertEqual(try expression.evaluate() as Double?, nil)
    }

    func testCastNSNullResultAsOptionalDouble() {
        let expression = AnyExpression("null", constants: ["null": NSNull()])
        XCTAssertEqual(try expression.evaluate() as Double?, nil)
    }

    func testCastNilResultAsAny() {
        let expression = AnyExpression("nil")
        XCTAssertEqual("\(try expression.evaluate() as Any)", "nil")
    }

    func testCastNilResultAsOptionalAny() {
        let expression = AnyExpression("nil")
        XCTAssertNil(try expression.evaluate() as Any?)
    }

    func testCastNSNullResultAsAny() {
        let expression = AnyExpression("null", constants: ["null": NSNull()])
        XCTAssertEqual("\(try expression.evaluate() as Any)", "nil")
    }

    func testCastNSNullResultAsOptionalAny() {
        let expression = AnyExpression("nil", constants: ["null": NSNull()])
        XCTAssertNil(try expression.evaluate() as Any?)
    }

    func testCastBoolResultAsOptionalBool() {
        let expression = AnyExpression("5 > 4")
        XCTAssertEqual(try expression.evaluate() as Bool?, true)
    }

    func testCastBoolResultAsOptionalDouble() {
        let expression = AnyExpression("5 > 4")
        XCTAssertEqual(try expression.evaluate() as Double?, 1)
    }

    func testCastBoolResultAsImplicitlyUnwrappedOptionalDouble() {
        let expression = AnyExpression("5 > 4")
        XCTAssertEqual(try expression.evaluate() as Double!, 1)
    }

    func testCastStringAsSubstring() {
        let expression = AnyExpression("'foo'")
        XCTAssertEqual(try expression.evaluate(), Substring("foo"))
    }

    func testCastStringAsNSString() {
        let expression = AnyExpression("'foo'")
        XCTAssertEqual(try expression.evaluate(), "foo" as NSString)
    }

    func testCastStringAsOptionalNSString() {
        let expression = AnyExpression("'foo'")
        XCTAssertEqual(try expression.evaluate(), "foo" as NSString?)
    }

    func testCastSubstringAsString() {
        let expression = AnyExpression("foo", constants: [
            "foo": Substring("foo"),
        ])
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testCastSubstringAsNSString() {
        let expression = AnyExpression("foo", constants: [
            "foo": Substring("foo"),
        ])
        XCTAssertEqual(try expression.evaluate(), "foo" as NSString)
    }

    func testCastSubstringAsOptionalNSString() {
        let expression = AnyExpression("foo", constants: [
            "foo": Substring("foo"),
        ])
        XCTAssertEqual(try expression.evaluate(), "foo" as NSString?)
    }

    // MARK: Optimization

    func testStringLiteralsInlined() {
        let expression = AnyExpression("foo('bar', 'baz')")
        XCTAssertEqual(expression.symbols, [.function("foo", arity: 2)])
    }

    func testNumericConstantsInlined() {
        let expression = AnyExpression("foo(bar)", constants: ["bar": 5])
        XCTAssertEqual(expression.symbols, [.function("foo", arity: 1)])
    }

    func testStringConstantsInlined() {
        let expression = AnyExpression("foo(bar)", constants: ["bar": "bar"])
        XCTAssertEqual(expression.symbols, [.function("foo", arity: 1)])
    }

    func testVariableSymbolNotInlined() {
        var foo = 5
        let expression = AnyExpression("foo", options: .pureSymbols, symbols: [
            .variable("foo"): { _ in foo },
        ])
        XCTAssertEqual(expression.symbols, [.variable("foo")])
        XCTAssertEqual(try expression.evaluate(), foo)
        foo += 1
        XCTAssertEqual(try expression.evaluate(), foo)
    }

    func testArrayConstantsInlined() {
        let expression = AnyExpression("foo[bar]", constants: ["foo": ["baz"], "bar": 0])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate(), "baz")
    }

    func testArraySymbolNotInlined() {
        let expression = AnyExpression("foo[0]", options: .pureSymbols, symbols: [.array("foo"): { _ in 5 }])
        XCTAssertEqual(expression.symbols, [.array("foo")])
        XCTAssertEqual(expression.description, "foo[0]")
    }

    func testNullCoalescingOperatorInlined() {
        let expression = AnyExpression("maybe ?? 'foo'", constants: ["maybe": nil as Any? as Any])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testTimesOperatorInlinedForDoubles() {
        let expression = AnyExpression("5 * foo", constants: ["foo": 5])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate(), 25)
    }

    func testPlusOperatorInlinedForDoubles() {
        let expression = AnyExpression("5 + foo", constants: ["foo": 5])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate(), 10)
    }

    func testPlusOperatorInlinedForStrings() {
        let expression = AnyExpression("5 + foo", constants: ["foo": "bar"])
        XCTAssertEqual(expression.symbols, [])
        XCTAssertEqual(try expression.evaluate(), "5bar")
    }

    func testBooleanAndOperatorInlined() {
        let expression = AnyExpression("true && false")
        XCTAssertEqual(expression.symbols, [])
        XCTAssertFalse(try expression.evaluate())
    }

    func testPureFunctionResultNotMangledByInlining() {
        let expression = AnyExpression("foo('bar')", options: .pureSymbols, symbols: [
            .function("foo", arity: 1): { args in "foo\(args[0])" },
        ])
        XCTAssertEqual(try expression.evaluate(), "foobar")
        XCTAssertEqual(try expression.evaluate(), "foobar")
    }

    func testPureFunctionResultNotMangledByDeferredInlining() {
        let expression = AnyExpression("foo(5 + 6)", options: .pureSymbols, symbols: [
            .function("foo", arity: 1): { args in "foo\(args[0])" },
        ])
        XCTAssertEqual(try expression.evaluate(), "foo11.0")
        XCTAssertEqual(try expression.evaluate(), "foo11.0")
    }

    func testOptimizerDisabled() {
        let expression = AnyExpression("3 * 5", options: .noOptimize)
        XCTAssertEqual(expression.symbols, [.infix("*")])
        XCTAssertEqual(try expression.evaluate(), 15)
    }

    func testOptimizerDisabledWithPureSymbols() {
        let expression = AnyExpression("foo(3 * 5)", options: [.noOptimize, .pureSymbols], symbols: [
            .function("foo", arity: 1): { args in args[0] },
        ])
        XCTAssertEqual(expression.symbols, [.infix("*"), .function("foo", arity: 1)])
        XCTAssertEqual(try expression.evaluate(), 15)
    }

    // MARK: Symbol precedence

    func testConstantTakesPrecedenceOverSymbol() {
        let expression = AnyExpression(
            "foo",
            constants: ["foo": "foo"],
            symbols: [.variable("foo"): { _ in "bar" }]
        )
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    func testArrayConstantTakesPrecedenceOverSymbol() {
        let expression = AnyExpression(
            "foo[0]",
            constants: ["foo": ["foo"]],
            symbols: [.array("foo"): { _ in "bar" }]
        )
        XCTAssertEqual(try expression.evaluate(), "foo")
    }

    // MARK: Memory

    func testUnusedConstantsNotRetained() {
        weak var weakObject: NSObject?
        weak var weakString: NSString?
        let expression: AnyExpression
        do {
            let object = NSObject()
            weakObject = object
            let string = "foo" as NSString
            weakString = string
            expression = AnyExpression("foo + 5", constants: [
                "foo": string,
                "bar": object,
            ])
            _ = try! expression.evaluate() as String
        }
        XCTAssertNil(weakObject)
        XCTAssertNotNil(weakString)
    }

    func testUnusedSymbolsNotRetained() {
        weak var weakObject: NSObject?
        weak var weakString: NSString?
        let expression: AnyExpression
        do {
            let object = NSObject()
            weakObject = object
            let string = "foo" as NSString
            weakString = string
            expression = AnyExpression("foo + 5", symbols: [
                .variable("foo"): { _ in string },
                .variable("bar"): { _ in object },
            ])
            _ = try! expression.evaluate() as String
        }
        XCTAssertNil(weakObject)
        XCTAssertNotNil(weakString)
    }
}
