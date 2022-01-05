//
//  ParseEach.swift
//  
//
//  Created by David Peterson on 5/1/22.
//

import Parsing

/// Used by ``Parser/parse(each:to:) -> SwiftStatus`` to indicate if the closure wants to continue receiving future outputs.
public enum StreamStatus: Hashable {
    /// Provide more output
    case `continue`
    /// No more output wanted.
    case `finish`
}

extension Parser where Input: RangeReplaceableCollection {
    
    /// Iterates through the provided input, calling the `output` closure whenever a new result is provided.
    /// The closure returns either `.continue` to receive future outputs, or `.finish` to indicate no more `Output` values are desired.
    /// With either response, a final `nil` value is sent to close out the stream.
    ///
    /// - Parameters:
    ///   - each: The incoming `AnyIterator`
    ///   - to: The closure called with the next value, returning `.finish` or `.continue`.
    public func parse(
        each input: inout AnyIterator<Input>,
        to receiver: @escaping (Output?) -> StreamStatus
    ) {
        var buffer = Input()
        
        while let chunk = input.next() {
            buffer.append(contentsOf: chunk)
            if receiver(self.parse(&buffer)) == .finish {
                break
            }
        }
        
        // indicate the stream is done.
        let _ = receiver(nil)
    }
}

