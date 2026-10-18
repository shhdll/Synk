// Categories offered by the category chips on Home, Map and the filter
// sheet, with the words that place an activity in each one.
//
// Activities don't store a category yet (the create flow never sets
// category_label), so an activity belongs to every category whose keyword
// starts a word in its title or description. Activities matching none go
// under [kOtherCategory]. Order here is the chip order.
const Map<String, List<String>> kActivityCategories = {
  'Padel': ['padel'],
  'Tennis': ['tennis', 'squash'],
  'Table Tennis': ['table tennis', 'ping pong'],
  'Football': ['football', 'soccer'],
  'Basketball': ['basketball'],
  'Volleyball': ['volleyball'],
  'Bowling': ['bowling'],
  'Karting': ['karting', 'kart'],
  'Cycling': ['cycling', 'bike', 'biking'],
  'Running': ['run', 'jog', 'marathon'],
  'Hiking': ['hike', 'hiking', 'trail', 'walk'],
  'Climbing': ['climb'],
  'Camping': ['camp'],
  'Fitness': ['gym', 'workout', 'yoga', 'fitness'],
  'Swimming': ['swim'],
  'Coffee': ['coffee', 'cafe', 'café', 'chat'],
  'Cooking': ['cook', 'baking'],
  'Food': ['dinner', 'brunch', 'lunch', 'breakfast', 'food'],
  'Board Games': ['board game', 'cards', 'puzzle'],
  'Chess': ['chess'],
  'Escape Room': ['escape room'],
  'Gaming': ['gaming', 'video game', 'playstation', 'fifa'],
  'Movies': ['movie', 'cinema', 'film'],
  'Karaoke': ['karaoke', 'sing'],
  'Music': ['music', 'concert'],
  'Art': ['art', 'paint', 'draw', 'craft'],
  'Pottery': ['pottery', 'ceramic'],
  'Books': ['book', 'reading'],
  'Photography': ['photo'],
};

// Chip for activities that fit no category above.
const String kOtherCategory = 'Other';
