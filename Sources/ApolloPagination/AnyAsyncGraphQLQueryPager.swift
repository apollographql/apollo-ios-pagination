import Apollo
import ApolloAPI
import Combine

/// Type-erases a query pager, transforming data from a generic type to a specific type, often a view model or array of view models.
public class AnyAsyncGraphQLQueryPager<Model> {
  public typealias Output = Result<(Model, UpdateSource), Error>
  private let _subject: CurrentValueSubject<Output?, Never> = .init(nil)
  public var publisher: AnyPublisher<Output, Never> { _subject.compactMap({ $0 }).eraseToAnyPublisher() }
  public var cancellables = [AnyCancellable]()
  public let pager: any AsyncPagerType

  public var canLoadNext: Bool { get async { await pager.canLoadNext } }
  public var canLoadPrevious: Bool { get async { await pager.canLoadPrevious } }

  /// Type-erases a given pager, transforming data to a model as pagination receives new results.
  /// - Parameters:
  ///   - pager: Pager to type-erase.
  ///   - transform: Transformation from an initial page and array of paginated pages to a given view model.
  public init<Pager: AsyncGraphQLQueryPager<InitialQuery, NextQuery>, InitialQuery, NextQuery>(
    pager: Pager,
    transform: @escaping ([NextQuery.Data], InitialQuery.Data, [NextQuery.Data]) throws -> Model
  ) async {
    self.pager = pager
    await pager.subscribe { [weak self] result in
      guard let self else { return }
      let returnValue: Output

      switch result {
      case let .success(output):
        do {
          let transformedModels = try transform(output.previousPages, output.initialPage, output.nextPages)
          returnValue = .success((transformedModels, output.updateSource))
        } catch {
          returnValue = .failure(error)
        }
      case let .failure(error):
        returnValue = .failure(error)
      }

      _subject.send(returnValue)
    }.store(in: &cancellables)
  }

  /// Type-erases a given pager, transforming the initial page to an array of models, and the
  /// subsequent pagination to an additional array of models, concatenating the results of each into one array.
  /// - Parameters:
  ///   - pager: Pager to type-erase.
  ///   - initialTransform: Initial transformation from the initial page to an array of models.
  ///   - nextPageTransform: Transformation to execute on each subseqent page to an array of models.
  public convenience init<
    Pager: AsyncGraphQLQueryPager<InitialQuery, NextQuery>,
    InitialQuery,
    NextQuery,
    Element
  >(
    pager: Pager,
    initialTransform: @escaping (InitialQuery.Data) throws -> Model,
    pageTransform: @escaping (NextQuery.Data) throws -> Model
  ) async where Model: RangeReplaceableCollection, Model.Element == Element {
    await self.init(
      pager: pager,
      transform: { previousData, initialData, nextData in
        let previous = try previousData.flatMap { try pageTransform($0) }
        let initial = try initialTransform(initialData)
        let next = try nextData.flatMap { try pageTransform($0) }
        return previous + initial + next
      }
    )
  }

  /// Subscribe to the results of the pager, with the management of the subscriber being stored internally to the `AnyGraphQLQueryPager`.
  /// - Parameter completion: The closure to trigger when new values come in.
  public func subscribe(completion: @MainActor @escaping (Output) -> Void) {
    publisher.sink { result in
      Task { await completion(result) }
    }.store(in: &cancellables)
  }

  /// Load the next page, if available.
  /// - Parameters:
  ///   - cachePolicy: The Apollo `CachePolicy` to use. Defaults to `returnCacheDataAndFetch`.
  public func loadNext(
    cachePolicy: CachePolicy = .returnCacheDataAndFetch
  ) async throws {
    try await pager.loadNext(cachePolicy: cachePolicy)
  }

  /// Load the previous page, if available.
  /// - Parameters:
  ///   - cachePolicy: The Apollo `CachePolicy` to use. Defaults to `returnCacheDataAndFetch`.
  public func loadPrevious(
    cachePolicy: CachePolicy = .returnCacheDataAndFetch
  ) async throws {
    try await pager.loadPrevious(cachePolicy: cachePolicy)
  }

  /// Loads all pages.
  /// - Parameters:
  ///   - fetchFromInitialPage: Pass true to begin loading from the initial page; otherwise pass false.  Defaults to `true`.  **NOTE**: Loading all pages with this value set to `false` requires that the initial page has already been loaded previously.
  public func loadAll(
    fetchFromInitialPage: Bool = true
  ) async throws {
    try await pager.loadAll(fetchFromInitialPage: fetchFromInitialPage)
  }

  /// Discards pagination state and fetches the first page from scratch.
  /// - Parameter cachePolicy: The apollo cache policy to trigger the first fetch with. Defaults to `fetchIgnoringCacheData`.
  public func refetch(cachePolicy: CachePolicy = .fetchIgnoringCacheData) async {
    await pager.refetch(cachePolicy: cachePolicy)
  }

  /// Fetches the first page.
  public func fetch() async {
    await pager.fetch()
  }

  /// Resets pagination state and cancels further updates from the pager.
  public func cancel() async {
    await pager.cancel()
  }
}

extension AsyncGraphQLQueryPager {
  nonisolated func eraseToAnyPager<T>(
    transform: @escaping ([PaginatedQuery.Data], InitialQuery.Data, [PaginatedQuery.Data]) throws -> T
  ) async -> AnyAsyncGraphQLQueryPager<T> {
    await AnyAsyncGraphQLQueryPager(
      pager: self,
      transform: transform
    )
  }

  nonisolated func eraseToAnyPager<T, S: RangeReplaceableCollection>(
    initialTransform: @escaping (InitialQuery.Data) throws -> S,
    pageTransform: @escaping (PaginatedQuery.Data) throws -> S
  ) async -> AnyAsyncGraphQLQueryPager<S> where T == S.Element {
    await AnyAsyncGraphQLQueryPager(
      pager: self,
      initialTransform: initialTransform,
      pageTransform: pageTransform
    )
  }

  nonisolated func eraseToAnyPager<T, S: RangeReplaceableCollection>(
    transform: @escaping (InitialQuery.Data) throws -> S
  ) async -> AnyAsyncGraphQLQueryPager<S> where InitialQuery == PaginatedQuery, T == S.Element {
    await AnyAsyncGraphQLQueryPager(
      pager: self,
      initialTransform: transform,
      pageTransform: transform
    )
  }
}
