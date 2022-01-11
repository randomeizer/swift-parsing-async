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
    /// With either response, a final `nil` value is sent indicate the stream has closed.
    ///
    /// - Parameters:
    ///   - each: The incoming `AnyIterator`
    ///   - consume: Indicates whether to consume the `Input` as soon as possible (`.eagerly`) or late as possible (`.lazily`). Defaults to `.lazily`)
    ///   - to: The asynchronous closure called with the next value, returning `.finish` or `.continue`.
    public func parse(
        each input: inout AnyIterator<Input>,
        consume: StreamConsumption = .lazily,
        to receiver: @escaping (Output?) async -> StreamStatus
    ) async {
        var buffer = Input()
        var result: Output?
        
        while let chunk = input.next() {
            if Task.isCancelled { break }
            
            buffer.append(contentsOf: chunk)
            var copy = buffer
            result = parse(&copy)
            
            if result == nil || consume == .lazily && copy.isEmpty {
                continue
            }
            
            buffer = copy
            let status = await receiver(result)
            result = nil
            if status == .finish {
                break
            }

            await Task.yield()
        }
        
        if let last = result {
            let _ = await receiver(last)
        }
        
        // indicate the stream is done.
        let _ = await receiver(nil)
    }
    
    /// Iterates through the provided input, calling the `to` closure asynchronously whenever a new result is provided.
    /// The closure returns either `.continue` to receive future outputs, or `.finish` to indicate no more `Output` values are desired.
    /// With either response, a final `nil` value is sent to close out the stream.
    ///
    /// - Parameters:
    ///   - each: The incoming `AsyncIteratorProtocol` instance
    ///   - consume: Indicates whether to consume the `Input` as soon as possible (`.eagerly`) or late as possible (`.lazily`). Defaults to `.lazily`)
    ///   - to: The asynchronous closure called with the next value, returning `.finish` or `.continue`.
    public func parse<Iterator>(
        each input: inout Iterator,
        consume: StreamConsumption = .lazily,
        to receiver: @escaping (Output?) async throws -> StreamStatus
    ) async throws
    where Iterator: AsyncIteratorProtocol, Iterator.Element == Input
    {
        var buffer = Input()
        
        var result: Output?
        
        while let chunk = try await input.next() {
            if Task.isCancelled { break }
            
            buffer.append(contentsOf: chunk)
            var copy = buffer
            result = parse(&copy)
            
            if result == nil || consume == .lazily && copy.isEmpty {
                continue
            }
            
            buffer = copy
            let status = try await receiver(result)
            result = nil
            if status == .finish {
                break
            }
            
            await Task.yield()
        }
        
        if let last = result {
            let _ = try await receiver(last)
        }
        
        // indicate the stream is done.
        let _ = try await receiver(nil)
    }
    
    /// Iterates through the provided input, calling the `to` closure asynchronously whenever a new result is provided.
    /// The closure returns either `.continue` to receive future outputs, or `.finish` to indicate no more `Output` values are desired.
    /// With either response, a final `nil` value is sent to close out the stream.
    ///
    /// - Parameters:
    ///   - each: The incoming `AsyncSequence` instance
    ///   - consume: Indicates whether to consume the `Input` as soon as possible (`.eagerly`) or late as possible (`.lazily`). Defaults to `.lazily`)
    ///   - to: The asynchronous closure called with the next value, returning `.finish` or `.continue`.
    public func parse<Sequence>(
        each input: inout Sequence,
        consume: StreamConsumption = .lazily,
        to receiver: @escaping (Output?) async throws -> StreamStatus
    ) async throws
    where Sequence: AsyncSequence, Sequence.Element == Input {
        var iterator = input.makeAsyncIterator()
        try await parse(each: &iterator, consume: consume, to: receiver)
    }

    /// Iterates through the provided input, sending it to the returned `AsyncStream` when the accumulated input is parsable.
    ///
    /// - Parameter each: The iterator of inputs to be parsed.
    /// - Parameter consume: Indicates whether to consume the `Input` as soon as possible (`.eagerly`) or late as possible (`.lazily`). Defaults to `.lazily`)
    /// - Parameter bufferingPolicy: The buffering policy the `AsyncStream` will use.
    /// - Returns: The `AsyncStream` to receive the parsed values on.
    public func parse(
        each input: AnyIterator<Input>,
        consume: StreamConsumption = .lazily,
        bufferingPolicy limit: AsyncStream<Output>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Output> {
        AsyncStream(bufferingPolicy: limit) { continuation in
            Task {
                var iterator = input
                
                await parse(each: &iterator, consume: consume) { value in
                    guard let value = value else {
                        continuation.finish()
                        return .finish
                    }
                    
                    switch continuation.yield(value) {
                    case .enqueued, .dropped:
                        await Task.yield()
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
    
    
    /// Iterates through the provided `AsyncIteratorProtocol` instance, sending it to the
    /// returned `AsyncStream` when the accumulated input is parsable.
    ///
    /// - Parameter each: The iterator of inputs to be parsed.
    /// - Parameter consume: Indicates whether to consume the `Input` as soon as possible (`.eagerly`) or late as possible (`.lazily`). Defaults to `.lazily`)
    /// - Parameter bufferingPolicy: The buffering policy the `AsyncStream` will use.
    /// - Returns: The `AsyncStream` to receive the parsed values on.
    public func parse<Iterator>(
        each input: Iterator,
        consume: StreamConsumption = .lazily,
        bufferingPolicy limit: AsyncStream<Output>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Output>
    where Iterator: AsyncIteratorProtocol, Iterator.Element == Input
    {
        AsyncStream(bufferingPolicy: limit) { continuation in
            Task {
                var iterator = input
                
                try await parse(each: &iterator, consume: consume) { value in
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
    
    public func parse<Sequence>(
        each input: Sequence,
        consume: StreamConsumption = .lazily,
        bufferingPolity limit: AsyncStream<Output>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Output>
    where Sequence: AsyncSequence, Sequence.Element == Input
    {
        
        
        AsyncStream(bufferingPolicy: limit) { continuation in
            Task {
                var buffer = Input()
                
                var result: Output?
                
                for try await item in input {
                    if Task.isCancelled { break }
                    
                    buffer.append(contentsOf: item)
                    var copy = buffer
                    result = parse(&copy)
                    
                    guard let parsed = result else {
                        continue
                    }
                    
                    if consume == .lazily && copy.isEmpty {
                        continue
                    }
                    
                    buffer = copy
                    let status = continuation.yield(parsed)
                    result = nil
                    
                    switch status {
                    case .enqueued, .dropped:
                        await Task.yield()
                    case .terminated:
                        break
                    @unknown default:
                        break
                    }
                }
                
                if let result = result {
                    continuation.yield(result)
                }
                
                continuation.finish()
            }
        }
    }
}
