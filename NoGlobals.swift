//
//  NoGlobals.swift
//  Advent
//
//  Created by Johannes Brands on 24/12/2024.
//

import Foundation

//1. Encapsulation with Classes or Structs
//One of the most straightforward ways is to encapsulate your global variables within a class or struct:
//Singleton Pattern: Here, AppState is a singleton, ensuring only one instance exists. Use this pattern judiciously as it can introduce issues with testing and dependency injection.

// Instead of:
var globalVariable = "Global"

// Use:
class AppState {
    static var shared = AppState()
    var variable = "Encapsulated"
}

// Access like this:
//AppState.shared.variable


//2. Dependency Injection

protocol DataProvider {
    var someData: String { get set }
}

class DataProviderImpl: DataProvider {
    var someData: String = "Default Data"
}

class SomeViewController {
    let dataProvider: DataProvider
    
    init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
    }
    
    func doSomething() {
        print(dataProvider.someData)
    }
}

// Usage:
let dataProvider = DataProviderImpl()
let viewController = SomeViewController(dataProvider: dataProvider)


//3. Use of Enums for Namespacing
//If you need a set of related constants or variables, enums can serve as namespaces:

enum AppConstants {
    static let defaultTimeout: TimeInterval = 30
}

// Use like this:
//Timer.scheduledTimer(withTimeInterval: AppConstants.defaultTimeout, repeats: false) { _ in /* ... */ }


//4. Environment or Configuration Objects
//For configuration that might change between environments (like debug vs. release), consider using a configuration object:

struct AppConfig {
    let apiUrl: URL
    let isDebug: Bool
    
    static var current: AppConfig = {
        #if DEBUG
        return AppConfig(apiUrl: URL(string: "http://dev.example.com")!, isDebug: true)
        #else
        return AppConfig(apiUrl: URL(string: "http://prod.example.com")!, isDebug: false)
        #endif
    }()
}

// Usage:
//print(AppConfig.current.apiUrl)


//6. Refactoring Over Time
//Audit: Identify all uses of the global variable.
//Replace: Gradually replace each use with one of the above methods.
//Test: Ensure that the application behaves as expected after each change.
//
//Best Practices:
//Minimize State: Where possible, reduce the amount of state you need to manage by computing values on-the-fly or using immutable data structures.
//Testability: Each of these methods generally improves testability by allowing you to mock or replace dependencies.

