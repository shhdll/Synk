import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activity_filters.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/utils/fuzzy_search.dart';

void main() {
  bool finds(String query, String title, {String description = ''}) =>
      FuzzySearch.score(query, title: title, loose: [description]) != null;

  group('finds with typos', () {
    test('missing letter', () => expect(finds('padl', 'Padel'), isTrue));
    test('extra letter', () => expect(finds('paddel', 'Padel'), isTrue));
    test('wrong letter', () => expect(finds('pedel', 'Padel'), isTrue));
    test('swapped letters', () => expect(finds('padle', 'Padel'), isTrue));
    test('upper and lower case', () => expect(finds('PADEL', 'padel'), isTrue));
    test('two typos in a long word', () {
      expect(finds('footbol', 'Football'), isTrue);
      expect(finds('basktbal', 'Basketball'), isTrue);
    });
    test('typo in an unfinished word', () {
      expect(finds('basketb', 'Basketball'), isTrue);
      expect(finds('baskeb', 'Basketball'), isTrue);
    });
    test('typo in any word of the title', () {
      expect(finds('nigt', 'Padel night'), isTrue);
    });
  });

  group('finds unfinished words', () {
    test('start of a word', () => expect(finds('pad', 'Padel'), isTrue));
    test('one letter', () => expect(finds('p', 'Padel'), isTrue));
    test('one letter finds names with a word starting with it', () {
      expect(finds('p', 'Pool day'), isTrue);
      expect(finds('p', 'Paint Your Own Bear'), isTrue);
      expect(finds('b', 'Paint Your Own Bear'), isTrue);
      expect(finds('q', 'Padel'), isFalse);
      expect(finds('ب', 'بادل'), isTrue);
      expect(finds('ر', 'الرياض'), isTrue);
      expect(finds('ا', 'الرياض'), isTrue);
      expect(finds('ل', 'الرياض'), isFalse);
    });
    test('one or two letters ignore the description', () {
      expect(finds('p', 'x', description: 'pool day'), isFalse);
      expect(finds('po', 'x', description: 'pool day'), isFalse);
      expect(finds('poo', 'x', description: 'pool day'), isTrue);
    });
    test('not from the middle of a word', () {
      expect(finds('ball', 'Football'), isFalse);
      expect(finds('p', 'Escape room'), isFalse);
    });
    test('several words in any order', () {
      expect(finds('night pad', 'Padel night'), isTrue);
    });
  });

  group('Arabic', () {
    test('with or without ال', () {
      expect(finds('البادل', 'بادل'), isTrue);
      expect(finds('بادل', 'البادل'), isTrue);
    });
    test('أ إ آ and ا are the same', () {
      expect(finds('اسطبل', 'إسطبل'), isTrue);
      expect(finds('أمسية', 'امسيه'), isTrue);
    });
    test('ة and ه, ى and ي', () {
      expect(finds('رياضه', 'رياضة'), isTrue);
      expect(finds('مقهي', 'مقهى'), isTrue);
    });
    test('ignores diacritics and tatweel', () {
      expect(finds('كرة', 'كُرَة'), isTrue);
      expect(finds('قهوة', 'قهــوة'), isTrue);
    });
    test('typo', () => expect(finds('بولنغ', 'بولينغ'), isTrue));
    test('unfinished word', () => expect(finds('كر', 'كرة قدم'), isTrue));
    test('Arabic digits', () => expect(finds('٥', 'Padel 5v5'), isTrue));
  });

  group('does not find unrelated things', () {
    test('a different word', () {
      expect(finds('padel', 'Football'), isFalse);
      expect(finds('chess', 'Padel'), isFalse);
    });
    test('short words need to be typed right', () {
      // Three letters with a typo would match almost anything.
      expect(finds('pdl', 'Padel'), isFalse);
      expect(finds('car', 'Cat cafe'), isFalse);
    });
    test('the start of an unrelated longer word', () {
      // Found on a real activity: "padl" matched "pal" of "Palaces".
      expect(finds('padl', 'H8PJ+PC, Al Moqbel Palaces 13776'), isFalse);
      expect(finds('padl', 'Qiddiya Adventure'), isFalse);
      expect(finds('pool', 'Pottery Painting Workshop'), isFalse);
    });
    test('too many typos', () {
      expect(finds('pdlx', 'Padel'), isFalse);
      expect(finds('fotbl', 'Football'), isFalse);
    });
    test('every word has to match', () {
      expect(finds('padel chess', 'Padel night'), isFalse);
    });
    test('the description only matches as typed', () {
      expect(finds('racket', 'x', description: 'bring your racket'), isTrue);
      expect(finds('rackat', 'x', description: 'bring your racket'), isFalse);
    });
  });

  test('closer matches score lower', () {
    int? score(String q, String t) => FuzzySearch.score(q, title: t);
    expect(score('padel', 'Padel'), 0);
    expect(score('pad', 'Padel')! > score('padel', 'Padel')!, isTrue);
    expect(score('padl', 'Padel')! > score('pad', 'Padel')!, isTrue);
  });

  test('distance counts edits', () {
    expect(FuzzySearch.distance('padel', 'padel'), 0);
    expect(FuzzySearch.distance('padl', 'padel'), 1);
    expect(FuzzySearch.distance('padle', 'padel'), 1);
    expect(FuzzySearch.distance('', 'abc'), 3);
    expect(FuzzySearch.distance('kitten', 'sitting'), 3);
  });

  group('activity search', () {
    Activity activity(
      String id,
      String title, {
      String description = '',
      String location = 'Somewhere',
      String? address,
      String category = '',
      int inDays = 3,
    }) => Activity(
      id: id,
      title: title,
      description: description,
      location: location,
      locationAddress: address,
      categoryLabel: category,
      dateTime: DateTime.now().add(Duration(days: inDays)),
    );

    List<String> search(
      List<Activity> activities,
      String query, {
      SortOption? sort,
    }) => ActivityFilters.defaults
        .copyWith(sort: sort)
        .apply(activities, search: query)
        .map((a) => a.id)
        .toList();

    test('searches title, location, address, category and description', () {
      final all = [
        activity('title', 'Padel night'),
        activity('place', 'x', location: 'Kingdom Arena'),
        activity('address', 'x', address: 'Olaya St, Riyadh'),
        activity('category', 'x', category: 'Hiking'),
        activity('desc', 'x', description: 'bring your racket'),
      ];
      expect(search(all, 'padl'), ['title']);
      expect(search(all, 'kingdm'), ['place']);
      expect(search(all, 'olya'), ['address']);
      expect(search(all, 'hikng'), ['category']);
      expect(search(all, 'racket'), ['desc']);
    });

    test('"p" finds only names and places with a word starting with p', () {
      final all = [
        activity(
          'bear',
          'Paint Your Own Bear',
          location: 'Bear with us Studio',
        ),
        activity('pool', 'Pool day', location: 'STORM CLUB'),
        activity(
          'qiddiya',
          'Qiddiya Adventure',
          location: 'Six Flags Qiddiya City',
          address: 'H8PJ+PC, Al Moqbel Palaces',
          description: 'explore thrilling rides with people',
        ),
        activity('escape', 'Escape room', location: 'Riyadh'),
        activity('padel', 'Friday games', location: 'Padel Point'),
      ];
      // Names first, then places.
      expect(search(all, 'p'), ['bear', 'pool', 'padel']);
      expect(search(all, 'po'), ['pool', 'padel']);
    });

    test('exact matches come before typo matches', () {
      final all = [
        activity('typo', 'Pedel', inDays: 1),
        activity('exact', 'Padel', inDays: 5),
        activity('partial', 'Padelball', inDays: 2),
      ];
      expect(search(all, 'padel'), ['exact', 'partial', 'typo']);
    });

    test('a typo in the name beats a typo in the place', () {
      final all = [
        activity('place', 'Aquarabia', location: 'Aquarabia Qiddiya City'),
        activity('name', 'Qiddiya Adventure', inDays: 9),
      ];
      expect(search(all, 'qidiya'), ['name', 'place']);
    });

    test('equal matches stay soonest first', () {
      final all = [
        activity('later', 'Padel', inDays: 5),
        activity('sooner', 'Padel', inDays: 1),
      ];
      expect(search(all, 'padel'), ['sooner', 'later']);
    });

    test('a chosen sort still wins over match quality', () {
      final all = [
        activity('typo', 'Pedel', inDays: 1),
        activity('exact', 'Padel', inDays: 5),
      ];
      expect(search(all, 'padel', sort: SortOption.soonest), ['typo', 'exact']);
    });

    test('empty or blank search shows everything', () {
      final all = [activity('a', 'Padel'), activity('b', 'Chess')];
      expect(search(all, '').length, 2);
      expect(search(all, '   ').length, 2);
      expect(search(all, '!!').length, 2);
    });
  });
}
