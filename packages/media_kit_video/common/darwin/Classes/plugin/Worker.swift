import Foundation

// https://stackoverflow.com/questions/49043257/how-to-ensure-to-run-some-code-on-same-background-thread/49075382#49075382
class Worker {
  public typealias Job = () -> Void

  private let semaphore = DispatchSemaphore(value: 0)
  private let lock = NSRecursiveLock()
  private var thread: Thread!
  private var queue = [Job]()
  private var canceled: Bool = false

  init() {
    thread = Thread(block: loop)
    thread.start()
  }

  public func cancel() {
    signalCancel()
    thread.cancel()
  }

  public func enqueue(_ job: @escaping Job) {
    let accepted = locked {
      if canceled { return false }
      queue.append(job)
      return true
    }
    if accepted { semaphore.signal() }
  }

  private func loop() {
    while true {
      semaphore.wait()

      guard let job = getFirstJob() else { return }
      job()
    }
  }

  private func signalCancel() {
    locked {
      canceled = true
      queue.removeAll()
    }

    semaphore.signal()
  }

  private func getFirstJob() -> Job? {
    let job = locked {
      if canceled || queue.isEmpty { return nil as Job? }
      return queue.removeFirst()
    }

    return job
  }

  private func locked<T>(do block: () -> T) -> T {
    lock.lock()
    defer {
      lock.unlock()
    }

    return block()
  }
}
