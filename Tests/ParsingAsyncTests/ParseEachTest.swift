//
//  ParseEachTest.swift
//  
//
//  Created by David Peterson on 5/1/22.
//

import XCTest

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
        
        XCTAssertEqual(results, [1, 2, 3])
    }

}
