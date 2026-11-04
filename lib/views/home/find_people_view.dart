import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/friends_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/friends_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/empty_state.dart';
import 'widgets/friend_action_button.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/friends_list_widgets.dart';

// Search everyone on Synk by name or username to send friend requests.
class FindPeopleView extends StatefulWidget {
  const FindPeopleView({super.key});

  @override
  State<FindPeopleView> createState() => _FindPeopleViewState();
}

class _FindPeopleViewState extends State<FindPeopleView> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<FriendUser> _results = const [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Waits for a short pause in typing before searching.
  void _onChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isSearching = true);
    List<FriendUser> results;
    try {
      results = await FriendsController.instance.searchPeople(query);
    } catch (error) {
      debugPrint('SYNK: people search failed: $error');
      if (!mounted || query != _search.text) return;
      setState(() => _isSearching = false);
      SynkFeedback.showError(
        context,
        context.l10n.somethingWentWrongPleaseTryAgain,
      );
      return;
    }
    if (!mounted || query != _search.text) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
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
          context.l10n.findPeople,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: FriendsSearchField(
                controller: _search,
                hint: context.l10n.searchByNameOrUsername,
                onChanged: _onChanged,
                autofocus: true,
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_search.text.trim().isEmpty) {
      return EmptyState(
        icon: Icons.person_search_rounded,
        title: context.l10n.searchForPeopleOnSynk,
      );
    }

    if (_isSearching && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: SynkColors.orangeDark),
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.person_off_outlined,
        title: context.l10n.noPeopleFound,
        message: context.l10n.tryAnotherNameOrUsername,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        FriendsListCard(
          children: [
            for (final user in _results)
              FriendsPersonRow(
                user: user,
                onTap: () => openFriendProfile(context, user),
                trailing: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: FriendActionButton(user: user, compact: true),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
