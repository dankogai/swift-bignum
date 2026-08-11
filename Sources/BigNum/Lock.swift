//
//  Lock.swift -- the one piece of shared mutable state this package has, guarded.
//
//  `BigRat` and `BigFloat` memoise π/4, e, √2, ln 2 and ln 10 per precision, in
//  `static var`s.  Those are the only mutable globals here -- `BigInt`, `BigUInt`
//  and everything under them have none -- and until this file they were
//  unsynchronised.  That is worse than it sounds: the cached value owns a
//  reference-counted array, so two threads populating a memo at once corrupt a
//  refcount rather than merely disagreeing about a number, and the symptom is an
//  aborted process.  It showed up as one flaky Linux CI failure and took a
//  concurrent stress test under the thread sanitiser to pin down.
//
//  What guards them is a plain mutex, held only across a tuple copy or a tuple
//  assignment -- never across a computation.  The constants are cached by
//  double-checked read: snapshot under the lock, compute outside it, publish under
//  the lock.  That matters for more than throughput.  Computing one constant can
//  ask for another -- `BigFloat.E` delegates to `BigRat.E`, and `LN10` goes
//  through `log`, which wants `LN2` -- so a lock held across the computation would
//  have to be recursive to avoid deadlocking on itself.  Holding it only across
//  the copy sidesteps that: by the time anything nests, nothing is held.
//
//  Two threads can therefore compute the same constant at the same time, and one
//  of the two results is discarded.  That is a waste and not a bug: the value is a
//  deterministic function of the precision asked for, so both threads compute the
//  same number.
//
//  No dependency is available for this and none of the good options are portable.
//  `Synchronization.Mutex` needs Swift 6 and, on Apple platforms, an availability
//  annotation this package does not want; `NSLock` needs Foundation, which
//  `Sources/BigNum` imports nowhere; `os_unfair_lock` is Darwin-only.  A pthread
//  mutex is available wherever libm is, which is everywhere this package already
//  builds, and Windows gets an `SRWLOCK` instead.  Neither is recursive, and by
//  the argument above neither needs to be.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import CRT
import WinSDK
#endif

///
/// A mutex, and nothing more than a mutex.
///
/// The storage is a heap allocation rather than a stored property, because a
/// pthread mutex must not move once initialised and taking `&someProperty` gives
/// no such promise.
///
internal final class _Mutex {
    #if os(Windows)
    private let handle = UnsafeMutablePointer<SRWLOCK>.allocate(capacity: 1)
    internal init() { InitializeSRWLock(handle) }
    deinit { handle.deallocate() }
    @inline(__always) internal func withLock<T>(_ body: () throws -> T) rethrows -> T {
        AcquireSRWLockExclusive(handle)
        defer { ReleaseSRWLockExclusive(handle) }
        return try body()
    }
    #else
    private let handle = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    internal init() {
        let status = pthread_mutex_init(handle, nil)
        precondition(status == 0, "pthread_mutex_init failed with \(status)")
    }
    deinit {
        pthread_mutex_destroy(handle)
        handle.deallocate()
    }
    @inline(__always) internal func withLock<T>(_ body: () throws -> T) rethrows -> T {
        pthread_mutex_lock(handle)
        defer { pthread_mutex_unlock(handle) }
        return try body()
    }
    #endif
}

/// The one lock, shared by every memoised constant of every type.
///
/// One rather than one per constant: the critical sections are a tuple copy and a
/// tuple assignment, so contention is not the cost worth optimising, and a single
/// lock cannot be got into a cycle with itself the way several can.  `static let`
/// initialisation is itself thread-safe, which is what makes this safe to reach
/// from anywhere without ordering rules.
internal let _memoLock = _Mutex()
