import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

// A place returned by search, or fully resolved after selection.
//
// [placeId] is always present — it's how a follow-up Details request is
// made. [address], [latitude] and [longitude] are null until [PlaceSearchModel
// .getDetails] has been called for this suggestion; a raw autocomplete result
// carries only a name and a placeId.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  // Returns a copy with the Details fields filled in, keeping the name that
  // came from autocomplete — the Details call intentionally never requests
  // displayName, to stay on Places Details Essentials pricing.
  PlaceSuggestion withDetails({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    return PlaceSuggestion(
      placeId: placeId,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

// Thrown when the places-proxy Edge Function returns an error, or its
// response can't be parsed. The message is safe to show to the user or log —
// it never contains the Places API key, which this model never sees.
class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);

  final String message;

  @override
  String toString() => 'PlaceSearchException: $message';
}

// Finds and resolves places for the location step, via the places-proxy
// Supabase Edge Function. The Google Places API key is never held here, sent
// from here, or visible to this app at all — the function holds it
// server-side and this model only calls the function, authenticated by the
// signed-in user's session (handled automatically by supabase_flutter).
//
// Stateless by design: the caller owns the autocomplete session's lifetime
// and passes the same [sessionToken] into every [search] call and the one
// [getDetails] call that follows, so one location search is billed as one
// Places session rather than as separate metered requests.
class PlaceSearchModel {
  PlaceSearchModel();

  static const String _functionName = 'places-proxy';

  final SupabaseClient _supabase = Supabase.instance.client;

  // Generates a fresh RFC 4122 UUID v4 to use as an autocomplete session
  // token. Call this once when a location search begins (e.g. when the
  // search sheet opens), and pass the same value to every [search] call and
  // the eventual [getDetails] call for that search.
  static String newSessionToken() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Force the version (4) and variant (RFC 4122) bits per the UUID v4 spec.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  // Returns place suggestions for [query], or an empty list for a blank
  // query. Throws [PlaceSearchException] on any failure — callers decide how
  // to surface that, this model doesn't swallow errors.
  Future<List<PlaceSuggestion>> search(
    String query, {
    required String sessionToken,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return const <PlaceSuggestion>[];

    final Map<String, dynamic> data = await _invoke(<String, dynamic>{
      'action': 'autocomplete',
      'input': trimmed,
      'sessionToken': sessionToken,
    });

    final List<dynamic> suggestions =
        (data['suggestions'] as List<dynamic>?) ?? const <dynamic>[];

    return suggestions
        .map((dynamic entry) => _parseAutocompleteSuggestion(
              entry as Map<String, dynamic>,
            ))
        .whereType<PlaceSuggestion>()
        .toList();
  }

  // Resolves [suggestion] to its formatted address and coordinates. The name
  // on the returned PlaceSuggestion is the same one autocomplete already
  // gave us — see PlaceSuggestion.withDetails.
  Future<PlaceSuggestion> getDetails(
    PlaceSuggestion suggestion, {
    required String sessionToken,
  }) async {
    final Map<String, dynamic> data = await _invoke(<String, dynamic>{
      'action': 'details',
      'placeId': suggestion.placeId,
      'sessionToken': sessionToken,
    });

    final String? address = data['formattedAddress'] as String?;
    final Map<String, dynamic>? location =
        data['location'] as Map<String, dynamic>?;
    final num? lat = location?['latitude'] as num?;
    final num? lng = location?['longitude'] as num?;

    if (address == null || lat == null || lng == null) {
      throw const PlaceSearchException(
        'The selected place is missing its address or coordinates.',
      );
    }

    return suggestion.withDetails(
      address: address,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
  }

  // Calls places-proxy and returns its decoded JSON body. The user's session
  // JWT is attached automatically by supabase_flutter — this model never
  // handles auth or the Places API key itself.
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final FunctionResponse response;
    try {
      response = await _supabase.functions.invoke(
        _functionName,
        body: body,
      );
    } on FunctionException catch (error) {
      throw PlaceSearchException(
        'Place search failed (${error.status}). Please try again.',
      );
    } catch (_) {
      throw const PlaceSearchException(
        'Could not reach place search. Check your connection and try again.',
      );
    }

    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    }

    throw const PlaceSearchException('Place search returned an unexpected response.');
  }

  PlaceSuggestion? _parseAutocompleteSuggestion(Map<String, dynamic> entry) {
    final Map<String, dynamic>? prediction =
        entry['placePrediction'] as Map<String, dynamic>?;
    if (prediction == null) return null; // e.g. a queryPrediction, not a place

    final String? placeId = prediction['placeId'] as String?;
    if (placeId == null) return null;

    final Map<String, dynamic>? structured =
        prediction['structuredFormat'] as Map<String, dynamic>?;
    final String? mainText =
        (structured?['mainText'] as Map<String, dynamic>?)?['text'] as String?;
    final String? fullText =
        (prediction['text'] as Map<String, dynamic>?)?['text'] as String?;
    // Already present in the autocomplete response the proxy passes through
    // unfiltered — just wasn't being read. Shown as the result row's muted
    // secondary line; getDetails() still overwrites `address` with the
    // authoritative formatted address once a place is selected.
    final String? secondaryText =
        (structured?['secondaryText'] as Map<String, dynamic>?)?['text']
            as String?;

    final String name = mainText ?? fullText ?? '';
    if (name.isEmpty) return null;

    return PlaceSuggestion(placeId: placeId, name: name, address: secondaryText);
  }
}