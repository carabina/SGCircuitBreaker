//MIT License
//
//Copyright (c) 2017 Manny Guerrero
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

import Foundation

// MARK: - Breaker State Enum

/// An enum that defines the different states a circut breaker can have.
///
/// - open: When the circut breaker is triped from an error. This means the cicuit breaker is broken.
/// - halfOpened: When the timeout has been reset. This means the circuit breaker is experiencing errors.
/// - closed: When the circut breaker can execute the context closure. This means that the cicuit breaker is
///           functioning normally.
public enum BreakerState {
    case open
    case halfOpened
    case closed
}


// MARK: - Circuit Breaker

/// A class that encapsulates the circuit breaker design pattern.
public class SGCircuitBreaker {
    
    // MARK: - Public Instance Attributes For Circuit Breaker Behavior
    
    /// Closure that represents the registered work that should be executed but could fail.
    public var workToPerform: ((SGCircuitBreaker) -> Void)?
    
    /// Closure that represents the registered error handler for when an error occurs in the circuit breaker.
    /// This can be fired if the registered work keeps failing and the max number of retries has been reached.
    public var tripped: ((SGCircuitBreaker, Error?) -> Void)?
    
    /// Number of failures allowed for retrying to performing the registered work before tripping.
    public let maxFailures: Int
    
    /// The current state of the circuit breaker.
    public var state: BreakerState {
        if let lastFailureTime = self.lastFailureTime,
           failureCount > maxFailures &&
           (Date().timeIntervalSince1970 - lastFailureTime) > retryDelay {
            return .halfOpened
        }
        if failureCount == maxFailures {
            return .open
        }
        return .closed
    }
    
    
    // MARK: - Public Instance Attributes For Timer
    
    /// How long the registered work has to finish before throwing an error.
    public let timeout: TimeInterval
    
    /// How long to wait before retrying the registered work after a failure.
    public let retryDelay: TimeInterval
    
    
    // MARK: - Private Instance Attributes For Circuit Breaker Behavior
    
    /// Current number of failures.
    private(set) var failureCount = 0
    
    /// The last reported error.
    private var lastError: Error?
    
    
    // MARK: - Private Instance Attributes For Timer
    
    /// The timer to use.
    private var timer: Timer?
    
    /// The time interval for the last failure.
    private var lastFailureTime: TimeInterval?
    
    
    // MARK: - Initializers
    
    /// Initializes an instance of `SGCircuitBreaker`
    ///
    /// - Parameters:
    ///   - timeout: A `TimeInterval` representing how long the registered work has to finish before throwing
    ///              an error. Defaults to 10.
    ///   - maxFailures: An `Int` representing the number of failures allowed for retrying to performing the
    ///                  registered work before tripping. Defaults to 3.
    ///   - retryDelay: A `TimeInterval` representing how long to wait before retrying the registered work
    ///                 after a failure. Defailts to 2.
    public init(timeout: TimeInterval = 10, maxFailures: Int = 3, retryDelay: TimeInterval = 2) {
        self.timeout = timeout
        self.maxFailures = maxFailures
        self.retryDelay = retryDelay
    }
}


// MARK: - Public Instance Methods For Beginning
public extension SGCircuitBreaker {
    
    /// Starts the circuit breaker.
    func start() {
        timer?.invalidate()
        switch state {
        case .open:
            tripCircuit()
        case .halfOpened, .closed:
            beginWork()
        }
    }
}


// MARK: - Public Instance Methods For Registering Success/Failure
public extension SGCircuitBreaker {
    
    /// Reports to the circuit breaker that the registered work was successful.
    func success() {
        reset()
    }
    
    /// Reports to the circuit breaker that the registered work failed.
    ///
    /// - Parameter error: An `Error` representing the error that occured.
    func failure(error: Error? = nil) {
        timer?.invalidate()
        lastError = error
        failureCount += 1
        lastFailureTime = Date().timeIntervalSince1970
        switch state {
        case .open:
            tripCircuit()
            break
        case .halfOpened, .closed:
            startRetryDelayTimer()
            break
        }
    }
}


// MARK: - Public Instance Methods For Resetting
public extension SGCircuitBreaker {
    
    /// Resets the circuit breaker.
    func reset() {
        timer?.invalidate()
        failureCount = 0
        lastFailureTime = nil
        lastError = nil
    }
}


// MARK: - Private Instance Methods For Timer
private extension SGCircuitBreaker {
    
    /// Starts the timer for when the registered work timesout.
    func startTimeoutTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.failure()
        }
    }
    
    func startRetryDelayTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            self?.beginWork()
        }
    }
}


// MARK: - Private Instance Methods For Circuit Breaker Behavior
private extension SGCircuitBreaker {
    
    /// Trips the circuit from an error.
    func tripCircuit() {
        tripped?(self, lastError)
        reset()
    }
    
    /// Begins the work to be performed.
    func beginWork() {
        workToPerform?(self)
        startTimeoutTimer()
    }
}
