//
//  ParseEach.swift
//  
//
//  Created by David Peterson on 5/1/22.
//

import Parsing

/// Used by ``Parser/parse(each:to:) -> Parser.SwiftStatus`` to indicate if the closure wants to continue receiving future outputs.
extension Parsers {
    public enum StreamStatus: Hashable {
        /// Provide more output
        case `continue`
        /// No more output wanted.
        case `finish`
    }
    
    /// Indicates whether a positive parse should return immediately when the current stream data parses (`.eagerly`),
    /// or wait until either there is unconsumed values in the `Input`, or the incoming stream ends (`.lazily`).
    public enum StreamConsumption {
        case eagerly
        case lazily
    }
}

extension Parser where Input: RangeReplaceableCollection {
    public typealias StreamStatus = Parsers.StreamStatus
    public typealias StreamConsumption = Parsers.StreamConsumption
}

extension Parser where Input: RangeReplaceableCollection {
    
    /// Iterates through the provided input, calling the `output` closure whenever a new result is provided.
    /// The closure returns either `.continue` to receive future outputs, or `.finish` to indicate no more `Output` values are desired.
    /// With either response, a final `nil` value is sent to close out the stream.
    ///
    /// - Parameters:
    ///   - each: The incoming `AnyIterator`
    ///   - consume: Indicates whether to consume the `Input` as soon as possible (`.eagerly`) or late as possible (`.lazily`). Defaults to `.lazily`
    ///   - to: The closure called with the next value, returning `.finish` or `.continue`.
    public func parse(
        each input: inout AnyIterator<Input>,
        consume: StreamConsumption = .lazily,
        to receiver: @escaping (Output?) -> StreamStatus
    ) {
        var buffer = Input()
        
        var result: Output?
        
        while let chunk = input.next() {
            buffer.append(contentsOf: chunk)
            var copy = buffer
            result = parse(&copy)
            
            if result == nil || consume == .lazily && copy.isEmpty {
                continue
            }
            
            buffer = copy
            let status = receiver(result)
            result = nil
            if status == .finish {
                break
            }
        }
        
        if let last = result {
            let _ = receiver(last)
        }
        
        // indicate the stream is done.
        let _ = receiver(nil)
    }
}

