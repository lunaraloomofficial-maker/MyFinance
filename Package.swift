// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MyFinanceCore", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "MyFinanceCore", targets: ["MyFinanceCore"])], targets: [.target(name: "MyFinanceCore", path: "MyFinance/Core/Finance"), .testTarget(name: "MyFinanceCoreTests", dependencies: ["MyFinanceCore"], path: "MyFinanceTests/Core")])
