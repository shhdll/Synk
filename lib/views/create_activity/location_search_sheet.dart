import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/place_search_model.dart';

class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({super.key});

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  static const Duration _debounce = Duration(milliseconds: 300);

  final PlaceSearchModel _model = PlaceSearchModel();
  final TextEditingController _query = TextEditingController();
  late final String _sessionToken = PlaceSearchModel.newSessionToken();

  Timer? _debounceTimer;
  List<PlaceSuggestion> _results = const <PlaceSuggestion>[];
  bool _isSearching = false;
  bool _isResolving = false; // true while a tapped suggestion's Details load
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _query.addListener(_onQueryTextChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryTextChanged);
    _debounceTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryTextChanged() {
    if (mounted) setState(() {});
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _search(value));
  }

  void _clearQuery() {
    _debounceTimer?.cancel();
    _query.clear();
    _search('');
  }

  Future<void> _search(String value) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _results = const <PlaceSuggestion>[];
          _errorMessage = null;
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final List<PlaceSuggestion> results = await _model.search(
        trimmed,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;

      if (_query.text.trim() != trimmed) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } on PlaceSearchException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final PlaceSuggestion resolved = await _model.getDetails(
        suggestion,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      Navigator.of(context).pop(resolved);
    } on PlaceSearchException catch (error) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _errorMessage = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0x331E1C24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.searchForAPlace,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.locationSearchHint,
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB6B3BD),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 21,
                    color: SynkColors.textSecondary,
                  ),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                SynkColors.orangeDark,
                              ),
                            ),
                          ),
                        )
                      : (_query.text.isNotEmpty
                            ? IconButton(
                                onPressed: _clearQuery,
                                tooltip: context.l10n.clearSearch,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: SynkColors.textSecondary,
                                ),
                              )
                            : null),
                ),
              ),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: Color(0xFFE53935),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: _isResolving
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SynkColors.orangeDark,
                        ),
                      ),
                    )
                  : _results.isEmpty
                  ? _EmptySearchState(
                      text: _query.text.trim().isEmpty
                          ? context.l10n.startTypingToSearchRiyadhVenues
                          : (_isSearching ? '' : context.l10n.noMatchesFound),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final PlaceSuggestion suggestion = _results[index];
                        return _PlaceResultRow(
                          suggestion: suggestion,
                          onTap: () => _select(suggestion),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

class _PlaceResultRow extends StatelessWidget {
  const _PlaceResultRow({required this.suggestion, required this.onTap});

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? address = suggestion.address;
    final bool hasAddress = address != null && address.isNotEmpty;

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: hasAddress
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                height: 38,
                width: 38,
                decoration: const BoxDecoration(
                  color: Color(0x1FFF7A36),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  size: 19,
                  color: SynkColors.orangeDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      suggestion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    if (hasAddress) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 44,
              width: 44,
              decoration: const BoxDecoration(
                color: Color(0x1FFF7A36),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 21,
                color: SynkColors.orangeDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SynkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
