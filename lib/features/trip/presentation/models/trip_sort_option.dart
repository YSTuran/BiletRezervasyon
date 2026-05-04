enum TripSortOption {
  departureAscending,
  priceAscending,
  priceDescending,
  durationAscending;

  String get label => switch (this) {
    TripSortOption.departureAscending => 'En Erken Kalkis',
    TripSortOption.priceAscending => 'En Dusuk Fiyat',
    TripSortOption.priceDescending => 'En Yuksek Fiyat',
    TripSortOption.durationAscending => 'En Kisa Sure',
  };
}
