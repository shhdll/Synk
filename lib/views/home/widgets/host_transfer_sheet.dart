import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_participation_model.dart';
import '../../../models/avatar_uploader.dart';

// The joined participant chosen to become the new host.
class HostTransferCandidate {
  const HostTransferCandidate({required this.userId, required this.name});

  final String userId;
  final String name;
}


// caller confirms and performs the transfer.
Future<HostTransferCandidate?> showHostTransferSheet({
  required BuildContext context,
  required String activityId,
  required String hostId,
}) {
  return showModalBottomSheet<HostTransferCandidate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return HostTransferSheet(activityId: activityId, hostId: hostId);
    },
  );
}

class HostTransferSheet extends StatefulWidget {
  const HostTransferSheet({
    super.key,
    required this.activityId,
    required this.hostId,
  });

  final String activityId;
  final String hostId;

  @override
  State<HostTransferSheet> createState() => _HostTransferSheetState();
}

class _HostTransferSheetState extends State<HostTransferSheet> {
  final ActivityParticipationModel _participationModel =
      ActivityParticipationModel();

  List<HostTransferCandidate> _candidates = [];
  final Map<String, Map<String, dynamic>> _profiles = {};

  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isClosing = false;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  // Loads the current joined participants so the list is never stale.
  Future<void> _loadCandidates() async {
    final List<Map<String, dynamic>> rows;

    try {
      rows = await _participationModel.fetchJoinedParticipants(
        widget.activityId,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
      return;
    }

    if (!mounted) return;

    final candidates = <HostTransferCandidate>[];

    for (final row in rows) {
      final userId = row['user_id'] as String?;

      if (userId == null ||
          userId == widget.hostId ||
          row['status'] != 'joined') {
        continue;
      }

      final name = (row['full_name'] as String?)?.trim();

      candidates.add(
        HostTransferCandidate(
          userId: userId,
          name: name == null || name.isEmpty ? context.l10n.synkMember : name,
        ),
      );
      _profiles[userId] = row;
    }

    setState(() {
      _candidates = candidates;
      _selectedUserId = null;
      _isLoading = false;
    });
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    _loadCandidates();
  }

  // Pops at most once, so repeated taps cannot close the sheet underneath.
  void _close([HostTransferCandidate? candidate]) {
    if (_isClosing) return;

    _isClosing = true;
    Navigator.of(context).pop(candidate);
  }

  void _continue() {
    for (final candidate in _candidates) {
      if (candidate.userId == _selectedUserId) {
        _close(candidate);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.4;

    return SafeArea(
      // The sheet's own color runs under the navigation bar, so no grey
      // strip shows below it.
      bottom: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              context.l10n.chooseANewHost,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.thePersonYouChooseGetsFull,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SynkColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: _buildBody(),
            ),
            const SizedBox(height: 8),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(color: SynkColors.orangeDark),
        ),
      );
    }

    if (_loadFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.unableToLoadParticipantsPleaseTry,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Color(0xFFE85D5D),
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _retry,
              style: TextButton.styleFrom(
                foregroundColor: SynkColors.orangeDark,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                context.l10n.retry,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    if (_candidates.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          context.l10n.noOneCanTakeOverYet,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: SynkColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _candidates.length,
      itemBuilder: (context, index) {
        return _buildCandidateRow(_candidates[index]);
      },
    );
  }

  Widget _buildCandidateRow(HostTransferCandidate candidate) {
    final isSelected = candidate.userId == _selectedUserId;
    final profile = _profiles[candidate.userId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedUserId = candidate.userId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? SynkColors.orange.withValues(alpha: 0.14)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? SynkColors.orangeDark : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(
                avatarUrl: profile?['avatar_url'] as String?,
                gender: profile?['gender'] as String?,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    if (profile?['username'] is String) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${profile!['username']}',
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
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: SynkColors.orangeDark,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Uploaded photo, or the app's default avatar for the participant.
  Widget _buildAvatar({required String? avatarUrl, required String? gender}) {
    const size = 40.0;
    final fallback = AvatarUploader.defaultImageForGender(gender);
    final url = avatarUrl?.trim();
    final photo = url != null && url.startsWith('http')
        ? NetworkImage(url)
        : fallback;

    return ClipOval(
      child: Image(
        image: photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image(
          image: fallback,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => _close(),
              style: OutlinedButton.styleFrom(
                foregroundColor: SynkColors.textSecondary,
                side: BorderSide(
                  color: SynkColors.textSecondary.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.l10n.cancel,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedUserId == null ? null : _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: SynkColors.orangeDark,
                disabledBackgroundColor: SynkColors.orangeDark.withValues(
                  alpha: 0.5,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.l10n.continueButton,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
