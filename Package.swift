// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "apollo-ios-pagination",
  platforms: [
    .iOS(.v12),
    .macOS(.v10_14),
    .tvOS(.v12),
    .watchOS(.v5)
  ],
  products: [
    .library(name: "apollo-ios-pagination", targets: ["apollo-ios-pagination"]),
  ],
  targets: [
    .target(
      name: "apollo-ios-pagination"
    ),
    .testTarget(
      name: "apollo-ios-paginationTests",
      dependencies: ["apollo-ios-pagination"]
    ),
  ]
)
