//
//  ParseEachTest.swift
//  
//
//  Created by David Peterson on 5/1/22.
//

import XCTest
import Parsing
import ParsingAsync

class ParseEachTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testParseEach() throws {
        var strings = ["1"[...], "2"[...], "3"[...]].makeIterator()
        var iter = AnyIterator {
            strings.next()
        }
        
        var results: [Int] = []

        Int.parser(of: Substring.self).parse(each: &iter) { value in
            guard let value = value else {
                return .finish
            }
            results.append(value)
            return .continue
        }
        
        XCTAssertEqual(results, [123])
    }
    
    func testParseEachLazily() throws {
        var strings = ["1"[...], "2"[...], "a"[...]].makeIterator()
        var iter = AnyIterator {
            strings.next()
        }
        
        var results: [Int] = []

        Int.parser(of: Substring.self)
        .parse(each: &iter, consume: .lazily) { value in
            guard let value = value else {
                return .finish
            }
            results.append(value)
            return .continue
        }
        
        XCTAssertEqual(results, [12])
        XCTAssertEqual(strings.next(), nil)
    }

    func testParseEachEagerly() throws {
        var strings = ["1"[...], "2"[...], "a"[...]].makeIterator()
        var iter = AnyIterator {
            strings.next()
        }
        
        var results: [Int] = []

        Int.parser(of: Substring.self)
        .parse(each: &iter, consume: .eagerly) { value in
            guard let value = value else {
                return .finish
            }
            results.append(value)
            return .continue
        }
        
        XCTAssertEqual(results, [1, 2])
        XCTAssertEqual(strings.next(), nil)
    }
    
    func testParseEachLazilyMultiple() throws {
        var strings = ["1"[...], "2"[...], "a34"[...], "56b"[...]].makeIterator()
        
        var iter = AnyIterator {
            strings.next()
        }
        
        var results: [Int] = []
        
        Parse {
            Skip(Prefix(0...) { !$0.isNumber })
            Int.parser(of: Substring.self)
        }.parse(each: &iter, consume: .lazily) { value in
            guard let value = value else {
                return .finish
            }
            results.append(value)
            return .continue
        }
        
        XCTAssertEqual(results, [12, 3456])
        XCTAssertEqual(strings.next(), nil)
    }
}
