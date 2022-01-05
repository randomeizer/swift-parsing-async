//
//  StreamAsyncTest.swift
//  
//
//  Created by David Peterson on 5/1/22.
//

import XCTest
import Parsing

import ParsingAsync

@available(macOS 10.15, *)
class ParseEachAsync: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testParseEach() async throws {
        var strings = ["1"[...], "2"[...], "3"[...]].makeIterator()
        var iter = AnyIterator {
            strings.next()
        }
        
        actor Results {
            var data: [Int] = []
            
            func append(_ value: Int) {
                data.append(value)
            }
            
            func assert(_ expected: [Int]) {
                XCTAssertEqual(data, expected)
            }
        }
        
        let results = Results()
        
        await Int.parser(of: Substring.self).parse(each: &iter) { value in
            guard let value = value else {
                return .finish
            }
            await results.append(value)
            return .continue
        }
        
        await results.assert([1, 2, 3])
    }

    func testFiniteList() async throws {
        var strings = ["1"[...], "2"[...], "3"[...]].makeIterator()
        let iter = AnyIterator {
            strings.next()
        }
        
        let stream = Int.parser(of: Substring.self).parse(each: iter)
        
        var results: [Int] = []
        
        for await value in stream {
            results.append(value)
        }
        
        XCTAssertEqual(results, [1, 2, 3])
    }
    
    func testInfiniteList() async throws {
        var counter = 0
        let iter = AnyIterator<Substring> {
            counter = counter + 1
            return String(counter)[...]
        }
        
        let stream = Int.parser(of: Substring.self).parse(each: iter)
        
        var results: [Int] = []
        
        for await value in stream {
            results.append(value)
            if value >= 5 {
                break
            }
        }
        
        XCTAssertEqual(results, [1, 2, 3, 4, 5])
        XCTAssertTrue(counter >= 5)
        print("counter: \(counter)")
    }
}
