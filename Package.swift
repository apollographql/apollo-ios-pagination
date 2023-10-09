// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "apollo-ios-pagination",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6)
  ],
  products: [
    .library(name: "apollo-ios-pagination", targets: ["apollo-ios-pagination"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apollographql/apollo-ios.git",
      .upToNextMajor(from: "1.2.0")
    ),
  ],
  targets: [
    .target(
      name: "apollo-ios-pagination",
      dependencies: [
        .product(name: "Apollo", package: "apollo-ios"),
        .product(name: "ApolloAPI", package: "apollo-ios"),
      ]
    ),
  ]
)
