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

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        FriendsSearchField(
          controller: _search,
          focusNode: _searchFocus,
          hint: context.l10n.searchFriends,
          onChanged: (_) => setState(() {}),
          onSubmitted: _saveRecent,
        ),
        const SizedBox(height: 16),
        if (_searchFocus.hasFocus &&
            _search.text.trim().isEmpty &&
            _recent.isNotEmpty) ...[
          RecentSearchesList(
            recent: _recent,
            onTap: _runRecent,
            onRemove: _removeRecent,
          ),
          const SizedBox(height: 12),
        ],
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              context.l10n.noFriendsMatchYourSearch,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: SynkColors.textSecondary,
              ),
            ),
          )
        else
          FriendsListCard(
            children: [
              for (final friend in shown)
                FriendsPersonRow(
                  user: friend,
                  onTap: () {
                    if (_search.text.trim().isNotEmpty) {
                      _saveRecent(_search.text);
                    }
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
        // Not a friend yet? Search all of Synk with the same text.
        if (query.isNotEmpty) ...[
          const SizedBox(height: 16),
          FriendsListCard(
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
          ),
        ],
      ],
    );
  }
}
