/// Isolated Explore destinations. Each value has its own query, cache, and cursor.
enum ExploreSection {
  people,
  businesses,
  events,
  thingsToDo,
  food,
  bars,
  rentals,
  communities,
  groups,
}

extension ExploreSectionX on ExploreSection {
  String get label => switch (this) {
    ExploreSection.people => 'People',
    ExploreSection.businesses => 'Businesses',
    ExploreSection.events => 'Events',
    ExploreSection.thingsToDo => 'Things to Do',
    ExploreSection.food => 'Food',
    ExploreSection.bars => 'Bars',
    ExploreSection.rentals => 'Rentals',
    ExploreSection.communities => 'Communities',
    ExploreSection.groups => 'Groups',
  };

  /// Stable order for the Explore chip row.
  static const visible = <ExploreSection>[
    ExploreSection.people,
    ExploreSection.businesses,
    ExploreSection.events,
    ExploreSection.thingsToDo,
    ExploreSection.food,
    ExploreSection.bars,
    ExploreSection.rentals,
    ExploreSection.communities,
    ExploreSection.groups,
  ];
}
