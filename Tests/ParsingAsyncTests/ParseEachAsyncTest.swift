//
//  StreamAsyncTest.swift
//  
//
//  Created by David Peterson on 5/1/22.
//

import XCTest
import Parsing

import ParsingAsync

actor Results {
    var data: [Int] = []
    
    func append(_ value: Int) {
        data.append(value)
    }
    
    func assertEqual(_ expected: [Int]) {
        XCTAssertEqual(data, expected)
    }
}


@available(macOS 10.15, *)
class ParseEachAsync: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testParseEachLazily() async throws {
        var strings = ["1"[...], "2"[...], "3"[...]].makeIterator()
        var iter = AnyIterator {
            strings.next()
        }
        
        let results = Results()
        
        await Int.parser(of: Substring.self).parse(each: &iter) { value in
            guard let value = value else {
                return .finish
            }
            await results.append(value)
            return .continue
        }
        
        await results.assertEqual([123])
    }
    
    func testParseEachEagerly() async throws {
        var strings = ["1"[...], "2"[...], "3"[...]].makeIterator()
        var iter = AnyIterator {
            strings.next()
        }
        
        let results = Results()
        
        await Int.parser(of: Substring.self).parse(each: &iter, consume: .eagerly) { value in
            guard let value = value else {
                return .finish
            }
            await results.append(value)
            return .continue
        }
        
        await results.assertEqual([1, 2, 3])
    }

    
    func testParseEachAsync() async throws {
        let strings = ["1"[...], "2"[...], "3"[...]]
        let sequence = AsyncStream<Substring> { continuation in
            for string in strings {
                continuation.yield(string)
            }
            continuation.finish()
        }
        var iter = sequence.makeAsyncIterator()
        
        let results = Results()
        
        try await Int.parser(of: Substring.self).parse(each: &iter) { value in
            guard let value = value else {
                return .finish
            }
            await results.append(value)
            return .continue
        }
        
        await results.assertEqual([123])
    }

    func testFiniteStream() async throws {
        var strings = ["1"[...], "2"[...], "3"[...]].makeIterator()
        let iter = AnyIterator {
            strings.next()
        }
        
        let stream = Int.parser(of: Substring.self).parse(each: iter)
        
        var results: [Int] = []
        
        for await value in stream {
            results.append(value)
        }
        
        XCTAssertEqual(results, [123])
    }
    
    func testInfiniteStream() async throws {
        var counter = 0
        let iter = AnyIterator<Substring> {
            counter += 1
            return "\(counter)"[...]
        }
        
        let stream = Int.parser(of: Substring.self).parse(each: iter, consume: .eagerly)
        
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
    
    func testParseEachAsyncSequence() async throws {
        let strings = ["1"[...], "2"[...], "3"[...]]
        var sequence = AsyncStream<Substring> { continuation in
            for string in strings {
                continuation.yield(string)
            }
            continuation.finish()
        }

        let results = Results()
        
        try await Int.parser(of: Substring.self).parse(each: &sequence, consume: .eagerly) { value in
            guard let value = value else {
                return .finish
            }
            await results.append(value)
            return .continue
        }
        
        await results.assertEqual([1, 2, 3])

    }
    
    func testParseEachAsyncSequenceToAsyncStream() async throws {
        let strings = ["1"[...], "2"[...], "3"[...]]
        let sequence = AsyncStream<Substring> { continuation in
            for string in strings {
                continuation.yield(string)
            }
            continuation.finish()
        }

        var results: [Int] = []
        
        let result = Int.parser(of: Substring.self).parse(each: sequence, consume: .eagerly)
        
        for await value in result {
            results.append(value)
        }
        
        XCTAssertEqual(results, [1, 2, 3])
    }
    
    func testParseEachAsyncSequenceToAsyncStreamLazily() async throws {
        let strings = ["1"[...], "2"[...], "3"[...], "a"[...]]
        let sequence = AsyncStream<Substring> { continuation in
            for string in strings {
                continuation.yield(string)
            }
            continuation.finish()
        }

        var results: [Int] = []
        
        let result = Int.parser(of: Substring.self).parse(each: sequence, consume: .lazily)
        
        for await value in result {
            results.append(value)
        }
        
        XCTAssertEqual(results, [123])
    }


}
