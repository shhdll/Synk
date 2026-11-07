import 'package:flutter/material.dart';

import '../../controllers/friends_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/recent_searches.dart';
import 'find_people_view.dart';
import 'widgets/empty_state.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/friends_list_widgets.dart';
import 'widgets/recent_searches_list.dart';

// The user's friends. Friend requests live in the notification center.
class FriendsView extends StatefulWidget {
  const FriendsView({super.key});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  final FriendsController _friends = FriendsController.instance;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final RecentSearches _recentSearches = const RecentSearches(
    'friends_recent_searches',
  );
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _friends.addListener(_refresh);
    _friends.refresh();
    _searchFocus.addListener(_refresh);
    _recentSearches.load().then((recent) {
      if (mounted) setState(() => _recent = recent);
    });
  }

  Future<void> _saveRecent(String query) async {
    final recent = await _recentSearches.add(query);
    if (mounted) setState(() => _recent = recent);
  }

  Future<void> _removeRecent(String query) async {
    final recent = await _recentSearches.remove(query);
    if (mounted) setState(() => _recent = recent);
  }

  void _runRecent(String query) {
    _search.text = query;
    _search.selection = TextSelection.collapsed(offset: query.length);
    _saveRecent(query);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _cancelSearch() {
    _search.clear();
    _searchFocus.unfocus();
    setState(() {});
  }

  @override
  void dispose() {
    _friends.removeListener(_refresh);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      appBar: AppBar(
        backgroundColor: SynkColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        title: Text(
          context.l10n.friendsCount(_friends.friends.length),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.findPeople,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FindPeopleView()),
            ),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !_friends.hasLoaded ? _buildFirstLoad() : _buildFriends(),
      ),
    );
  }

  Widget _buildFirstLoad() {
    if (_friends.error == null) {
      return const Center(
        child: CircularProgressIndicator(color: SynkColors.orangeDark),
      );
    }
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: context.l10n.somethingWentWrong,
      message: context.l10n.checkYourConnectionAndTryAgain,
      actionLabel: context.l10n.tryAgain,
      onAction: _friends.refresh,
    );
  }

  Widget _buildFriends() {
    final all = _friends.friends;
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.people_alt_rounded,
        title: context.l10n.noFriendsYet,
        message: context.l10n.findPeopleYouKnow,
        actionLabel: context.l10n.findPeople,
        onAction: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const FindPeopleView())),
      );
    }

    final shown = _friends.searchFriends(_search.text);
    final query = _search.text.trim();
    final searching = _searchFocus.hasFocus || query.isNotEmpty;
    final showRecent =
        _searchFocus.hasFocus && query.isEmpty && _recent.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _buildSearchRow(searching),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      context.l10n.noFriendsMatchYourSearch,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  children: [
                    // Recent searches first, then the friends, as on Home.
                    // While the field is in use, recent searches take the
                    // place of the list, as on Home.
                    if (showRecent)
                      RecentSearchesList(
                        recent: _recent,
                        onTap: _runRecent,
                        onRemove: _removeRecent,
                      )
                    else
                      FriendsListCard(
                        children: [
                          for (final friend in shown)
                            FriendsPersonRow(
                              user: friend,
                              onTap: () {
                                if (query.isNotEmpty) _saveRecent(query);
                                openFriendProfile(context, friend);
                              },
                              trailing: IconButton(
                                tooltip: context.l10n.friendOptions,
                                onPressed: () => showFriendOptionsSheet(
                                  context: context,
                                  friend: friend,
                                ),
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: SynkColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
        // Not a friend yet? Search all of Synk with the same text. Kept at
        // the bottom so it sits right above the keyboard.
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _buildLookOnSynk(query),
          ),
      ],
    );
  }

  Widget _buildSearchRow(bool searching) {
    return Row(
      children: [
        Expanded(
          child: FriendsSearchField(
            controller: _search,
            focusNode: _searchFocus,
            hint: context.l10n.searchFriends,
            borderRadius: 24,
            onChanged: (_) => setState(() {}),
            onSubmitted: _saveRecent,
          ),
        ),
        if (searching) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: _cancelSearch,
            style: TextButton.styleFrom(
              foregroundColor: SynkColors.ink,
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              context.l10n.cancel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLookOnSynk(String query) {
    return FriendsListCard(
      children: [
        ListTile(
          onTap: () {
            _saveRecent(query);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FindPeopleView(initialQuery: query),
              ),
            );
          },
          leading: const Icon(
            Icons.person_search_rounded,
            color: SynkColors.orangeDark,
          ),
          title: Text(
            context.l10n.lookForQueryOnSynk(query),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SynkColors.textPrimary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: SynkColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
