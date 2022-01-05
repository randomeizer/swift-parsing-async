//
//  ParseEachAsync.swift
//
//
//  Created by David Peterson on 5/1/22.
//

import Parsing

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Parser where Input: RangeReplaceableCollection {

    /// Iterates through the provided input, calling the `output` closure asynchronously whenever a new result is provided.
    /// The closure returns either `.continue` to receive future outputs, or `.finish` to indicate no more `Output` values are desired.
    /// With either response, a final `nil` value is sent to close out the stream.
    ///
    /// - Parameters:
    ///   - each: The incoming `AnyIterator`
    ///   - to: The asynchronous closure called with the next value, returning `.finish` or `.continue`.
    public func parse(
        each input: inout AnyIterator<Input>,
        to receiver: @escaping (Output?) async -> StreamStatus
    ) async {
        var buffer = Input()
        
        while let chunk = input.next() {
            if Task.isCancelled {
                break
            }
            
            buffer.append(contentsOf: chunk)
            if await receiver(self.parse(&buffer)) == .finish {
                break
            }
            
            await Task.yield()
        }
        
        // indicate the stream is done.
        let _ = await receiver(nil)
    }

    /// Iterates through the provided input, sending it to the returned `AsyncStream` when the accumulated input is parsable.
    ///
    /// - Parameter each: The iterator of inputs to be parsed.
    /// - Parameter bufferingPolicy: The buffering policy the `AsyncStream` will use.
    /// - Returns: The `AsyncStream` to receive the parsed values on.
    public func parse(each input: AnyIterator<Input>, bufferingPolicy limit: AsyncStream<Output>.Continuation.BufferingPolicy = .unbounded) -> AsyncStream<Output> {
        AsyncStream(bufferingPolicy: limit) { continuation in
            Task {
                var iterator = input
                
                parse(each: &iterator) { value in
                    guard let value = value else {
                        continuation.finish()
                        return .finish
                    }
                    
                    switch continuation.yield(value) {
                    case .enqueued, .dropped:
                        return .continue
                    case .terminated:
                        return .finish
                    @unknown default:
                        return .finish
                    }
                }
            }
        }
    }
}
