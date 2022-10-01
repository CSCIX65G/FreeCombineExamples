import FreeCombine
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

let numbers = [5, 4, 3, 2, 1, 0]
let romanNumeralDict: [Int : String] = [1:"I", 2:"II", 3:"III", 4:"IV", 5:"V"]
let cancellable = await numbers.asyncPublisher
    .map { romanNumeralDict[$0] ?? "(unknown)" }
    .sink { result in
        switch result {
            case .value(let value):
                Swift.print("Value: \(value)")
                return .more
            case .completion(.finished):
                Swift.print("Completion: Finished")
                return .done
            case .completion(.failure(let error)):
                Swift.print("Completion: Error: \(error)")
                return .done
        }
    }

await cancellable.result
PlaygroundPage.current.finishExecution()
