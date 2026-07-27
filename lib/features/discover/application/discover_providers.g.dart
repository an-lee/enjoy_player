// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(discoverRepository)
final discoverRepositoryProvider = DiscoverRepositoryProvider._();

final class DiscoverRepositoryProvider
    extends
        $FunctionalProvider<
          DiscoverRepository,
          DiscoverRepository,
          DiscoverRepository
        >
    with $Provider<DiscoverRepository> {
  DiscoverRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverRepositoryHash();

  @$internal
  @override
  $ProviderElement<DiscoverRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiscoverRepository create(Ref ref) {
    return discoverRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoverRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoverRepository>(value),
    );
  }
}

String _$discoverRepositoryHash() =>
    r'a43f357194cd59c2f4c15142d44c8229cd38deee';

@ProviderFor(recommendedChannels)
final recommendedChannelsProvider = RecommendedChannelsProvider._();

final class RecommendedChannelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecommendedChannel>>,
          List<RecommendedChannel>,
          FutureOr<List<RecommendedChannel>>
        >
    with
        $FutureModifier<List<RecommendedChannel>>,
        $FutureProvider<List<RecommendedChannel>> {
  RecommendedChannelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recommendedChannelsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recommendedChannelsHash();

  @$internal
  @override
  $FutureProviderElement<List<RecommendedChannel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecommendedChannel>> create(Ref ref) {
    return recommendedChannels(ref);
  }
}

String _$recommendedChannelsHash() =>
    r'7490234ebc0cf57d8766c20be2fb4e0caa946509';

/// When false, recommended channels are filtered to the user's focus learning language.

@ProviderFor(DiscoverRecommendedShowAllLanguages)
final discoverRecommendedShowAllLanguagesProvider =
    DiscoverRecommendedShowAllLanguagesProvider._();

/// When false, recommended channels are filtered to the user's focus learning language.
final class DiscoverRecommendedShowAllLanguagesProvider
    extends $NotifierProvider<DiscoverRecommendedShowAllLanguages, bool> {
  /// When false, recommended channels are filtered to the user's focus learning language.
  DiscoverRecommendedShowAllLanguagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverRecommendedShowAllLanguagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$discoverRecommendedShowAllLanguagesHash();

  @$internal
  @override
  DiscoverRecommendedShowAllLanguages create() =>
      DiscoverRecommendedShowAllLanguages();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$discoverRecommendedShowAllLanguagesHash() =>
    r'eb8a9ae4970137b1b8863d44923e41eab4389979';

/// When false, recommended channels are filtered to the user's focus learning language.

abstract class _$DiscoverRecommendedShowAllLanguages extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(filteredRecommendedChannels)
final filteredRecommendedChannelsProvider =
    FilteredRecommendedChannelsProvider._();

final class FilteredRecommendedChannelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecommendedChannel>>,
          List<RecommendedChannel>,
          FutureOr<List<RecommendedChannel>>
        >
    with
        $FutureModifier<List<RecommendedChannel>>,
        $FutureProvider<List<RecommendedChannel>> {
  FilteredRecommendedChannelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredRecommendedChannelsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredRecommendedChannelsHash();

  @$internal
  @override
  $FutureProviderElement<List<RecommendedChannel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecommendedChannel>> create(Ref ref) {
    return filteredRecommendedChannels(ref);
  }
}

String _$filteredRecommendedChannelsHash() =>
    r'cd33834b91388167f363ed46da25fd2d02a5de79';

@ProviderFor(discoverSubscriptions)
final discoverSubscriptionsProvider = DiscoverSubscriptionsProvider._();

final class DiscoverSubscriptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DiscoverChannel>>,
          List<DiscoverChannel>,
          Stream<List<DiscoverChannel>>
        >
    with
        $FutureModifier<List<DiscoverChannel>>,
        $StreamProvider<List<DiscoverChannel>> {
  DiscoverSubscriptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverSubscriptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverSubscriptionsHash();

  @$internal
  @override
  $StreamProviderElement<List<DiscoverChannel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DiscoverChannel>> create(Ref ref) {
    return discoverSubscriptions(ref);
  }
}

String _$discoverSubscriptionsHash() =>
    r'30c532b4d8eb38cd4f39d8efe3333d6b41ce5ce4';

@ProviderFor(discoverTimeline)
final discoverTimelineProvider = DiscoverTimelineProvider._();

final class DiscoverTimelineProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FeedEntry>>,
          List<FeedEntry>,
          Stream<List<FeedEntry>>
        >
    with $FutureModifier<List<FeedEntry>>, $StreamProvider<List<FeedEntry>> {
  DiscoverTimelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverTimelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverTimelineHash();

  @$internal
  @override
  $StreamProviderElement<List<FeedEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<FeedEntry>> create(Ref ref) {
    return discoverTimeline(ref);
  }
}

String _$discoverTimelineHash() => r'3e942de2ba42045ba9935cc68b25c1d12896de33';

@ProviderFor(filteredDiscoverTimeline)
final filteredDiscoverTimelineProvider = FilteredDiscoverTimelineProvider._();

final class FilteredDiscoverTimelineProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FeedEntry>>,
          List<FeedEntry>,
          Stream<List<FeedEntry>>
        >
    with $FutureModifier<List<FeedEntry>>, $StreamProvider<List<FeedEntry>> {
  FilteredDiscoverTimelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredDiscoverTimelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredDiscoverTimelineHash();

  @$internal
  @override
  $StreamProviderElement<List<FeedEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<FeedEntry>> create(Ref ref) {
    return filteredDiscoverTimeline(ref);
  }
}

String _$filteredDiscoverTimelineHash() =>
    r'aade702de97bb2e869f9cbf9eeeded4de3bc80dd';

@ProviderFor(discoverChannelFeed)
final discoverChannelFeedProvider = DiscoverChannelFeedFamily._();

final class DiscoverChannelFeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FeedEntry>>,
          List<FeedEntry>,
          Stream<List<FeedEntry>>
        >
    with $FutureModifier<List<FeedEntry>>, $StreamProvider<List<FeedEntry>> {
  DiscoverChannelFeedProvider._({
    required DiscoverChannelFeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'discoverChannelFeedProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$discoverChannelFeedHash();

  @override
  String toString() {
    return r'discoverChannelFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<FeedEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<FeedEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return discoverChannelFeed(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoverChannelFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$discoverChannelFeedHash() =>
    r'7b4a4c6a9ed00b845c1464128ccc361ea96b0f92';

final class DiscoverChannelFeedFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<FeedEntry>>, String> {
  DiscoverChannelFeedFamily._()
    : super(
        retry: null,
        name: r'discoverChannelFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  DiscoverChannelFeedProvider call(String channelId) =>
      DiscoverChannelFeedProvider._(argument: channelId, from: this);

  @override
  String toString() => r'discoverChannelFeedProvider';
}

/// Active Discover feed filter: `null` = all subscribed channels, else one channel.

@ProviderFor(DiscoverSelectedChannel)
final discoverSelectedChannelProvider = DiscoverSelectedChannelProvider._();

/// Active Discover feed filter: `null` = all subscribed channels, else one channel.
final class DiscoverSelectedChannelProvider
    extends $NotifierProvider<DiscoverSelectedChannel, String?> {
  /// Active Discover feed filter: `null` = all subscribed channels, else one channel.
  DiscoverSelectedChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverSelectedChannelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverSelectedChannelHash();

  @$internal
  @override
  DiscoverSelectedChannel create() => DiscoverSelectedChannel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$discoverSelectedChannelHash() =>
    r'84d965d14d0532158236cfa8ed0a62386dfe9296';

/// Active Discover feed filter: `null` = all subscribed channels, else one channel.

abstract class _$DiscoverSelectedChannel extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Channel profile photo for recommended row: subscription avatar, bundled
/// URL, then a one-time fetch from the public channel page.

@ProviderFor(recommendedChannelAvatar)
final recommendedChannelAvatarProvider = RecommendedChannelAvatarFamily._();

/// Channel profile photo for recommended row: subscription avatar, bundled
/// URL, then a one-time fetch from the public channel page.

final class RecommendedChannelAvatarProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Channel profile photo for recommended row: subscription avatar, bundled
  /// URL, then a one-time fetch from the public channel page.
  RecommendedChannelAvatarProvider._({
    required RecommendedChannelAvatarFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recommendedChannelAvatarProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recommendedChannelAvatarHash();

  @override
  String toString() {
    return r'recommendedChannelAvatarProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return recommendedChannelAvatar(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecommendedChannelAvatarProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recommendedChannelAvatarHash() =>
    r'04113031fb065f04a7a4e54c542aa1c63a2c6291';

/// Channel profile photo for recommended row: subscription avatar, bundled
/// URL, then a one-time fetch from the public channel page.

final class RecommendedChannelAvatarFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  RecommendedChannelAvatarFamily._()
    : super(
        retry: null,
        name: r'recommendedChannelAvatarProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Channel profile photo for recommended row: subscription avatar, bundled
  /// URL, then a one-time fetch from the public channel page.

  RecommendedChannelAvatarProvider call(String channelId) =>
      RecommendedChannelAvatarProvider._(argument: channelId, from: this);

  @override
  String toString() => r'recommendedChannelAvatarProvider';
}

@ProviderFor(DiscoverRefreshState)
final discoverRefreshStateProvider = DiscoverRefreshStateProvider._();

final class DiscoverRefreshStateProvider
    extends $NotifierProvider<DiscoverRefreshState, bool> {
  DiscoverRefreshStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverRefreshStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverRefreshStateHash();

  @$internal
  @override
  DiscoverRefreshState create() => DiscoverRefreshState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$discoverRefreshStateHash() =>
    r'b4ded4ff642ff740385f05492ef3a8103945aa6e';

abstract class _$DiscoverRefreshState extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DiscoverFeedRefreshScheduler)
final discoverFeedRefreshSchedulerProvider =
    DiscoverFeedRefreshSchedulerProvider._();

final class DiscoverFeedRefreshSchedulerProvider
    extends $NotifierProvider<DiscoverFeedRefreshScheduler, int> {
  DiscoverFeedRefreshSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverFeedRefreshSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverFeedRefreshSchedulerHash();

  @$internal
  @override
  DiscoverFeedRefreshScheduler create() => DiscoverFeedRefreshScheduler();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$discoverFeedRefreshSchedulerHash() =>
    r'32d18862fc0c280a7c50f583221294b27353805a';

abstract class _$DiscoverFeedRefreshScheduler extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
