enum PublishDestination {
  feed('feed'),
  vue('vue'),
  feedAndVue('feed_and_vue'),
  entityOnly('entity_only');

  final String value;
  const PublishDestination(this.value);

  bool get appearsOnHome =>
      this == PublishDestination.feed || this == PublishDestination.feedAndVue;

  bool get appearsOnVue =>
      this == PublishDestination.vue || this == PublishDestination.feedAndVue;

  bool get isEntityIsolated => this == PublishDestination.entityOnly;

  static PublishDestination parse(String? raw) {
    return switch (raw) {
      'vue' => PublishDestination.vue,
      'feed_and_vue' => PublishDestination.feedAndVue,
      'entity_only' => PublishDestination.entityOnly,
      _ => PublishDestination.feed,
    };
  }
}
