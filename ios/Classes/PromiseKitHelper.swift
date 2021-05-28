//
//  PromiseKitHelper.swift
//  TrueID
//
//  Created by Kittiphat Srilomsak on 3/21/2560 BE.
//  Copyright © 2017 peatiscoding.me all rights reserved.
//
import PromiseKit

extension Promise {

  /// Returns a single Promise that you can chain to. Wraps the chains of promises passed into the array into a serial promise to execute one after another using `promise1.then { promise2 }.then ...`
  ///
  /// - Parameter promisesToExecuteSerially: promises to stitch together with `.then` and execute serially
  /// - Returns: returns an array of results from all promises
  public static func chainSerially<T>(_ promisesToExecuteSerially:[() -> Promise<T>]) -> Promise<[T]> {
    // Create an array of closures that return `Promise<T>`
    var promises = promisesToExecuteSerially.map { promise -> () -> Promise<T> in
      return { promise() }
    }

    // Return a single promise that is fullfilled when
    // all passed promises in the array are fullfilled serially
    return Promise<[T]> { seal in
      var outResults = [T]()

      if promises.count == 0 {
        seal.fulfill(outResults)
      } else {
        let initial = promises.removeFirst()
        let finalPromise: Promise<T> = promises.reduce(initial()) { (result: Promise<T>, next: @escaping ()->Promise<T>) in
          return result.then { result -> Promise<T> in
            outResults.append(result)

            return next()
          }
        }

        // Result of the final promise executed
        // and seal fullfilled here
        finalPromise.done { result -> Void in
          outResults.append(result)

          seal.fulfill(outResults)
        }.catch { error in
          seal.reject(error)
        }
      }
    }
  }
}
