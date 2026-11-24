import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/circle_service.dart';
import '../widgets/member_avatar.dart';
import '../widgets/app_toast.dart';

class CircleHubScreen extends StatefulWidget {
  const CircleHubScreen({super.key});

  @override
  State<CircleHubScreen> createState() => _CircleHubScreenState();
}

class _CircleHubScreenState extends State<CircleHubScreen> {
  final CircleService _circleService = CircleService();

  void _showCreateCircleDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedEmoji = '🔥';
    final emojis = ['🔥', '⚡', '💪', '🚀', '🎯', '📚', '🏃‍♂️', '🧘'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Create a Circle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick an emoji icon:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: emojis.map((e) {
                    final isSel = e == selectedEmoji;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedEmoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF2563EB).withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Circle Name',
                    hintText: 'e.g. Roommates, Morning Club',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Goal / Description',
                    hintText: 'e.g. Daily habits consistency challenge',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final id = await _circleService.createCircle(
                    name: name,
                    emoji: selectedEmoji,
                    description: descController.text.trim(),
                  );
                  if (mounted) {
                    AppToast.success(context, 'Circle created! Share code with friends.');
                    _openCircleDetail(id);
                  }
                } catch (e) {
                  if (mounted) {
                    AppToast.error(context, '$e');
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinCircleDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Join a Circle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 6-character invite code provided by your friend:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              decoration: const InputDecoration(
                hintText: 'CODE12',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final res = await _circleService.joinCircleByCode(code);
                if (mounted) {
                  AppToast.success(
                    context,
                    res['alreadyJoined'] == true
                        ? 'Already a member of ${res['name']}!'
                        : 'Joined ${res['name']} successfully!',
                  );
                  _openCircleDetail(res['id']);
                }
              } catch (e) {
                if (mounted) {
                  AppToast.error(context, '$e');
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _openCircleDetail(String circleId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: circleId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F1218) : const Color(0xFFF9FAFC);
    final cardBg = isDark ? const Color(0xFF181C26) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'StreakUP Circles',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _circleService.streamUserCircles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Top Action Banners
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showCreateCircleDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 28),
                              SizedBox(height: 12),
                              Text(
                                'Create Circle',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Start with friends',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showJoinCircleDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.group_add_outlined, color: textColor, size: 28),
                              SizedBox(height: 12),
                              Text(
                                'Join Circle',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Have an invite code?',
                                style: TextStyle(color: subTextColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                Text(
                  'My Active Circles (${docs.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),

                if (docs.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Text('👥', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No circles joined yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create a Circle or join one with your friends to keep each other accountable!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: subTextColor),
                        ),
                      ],
                    ),
                  )
                else
                  ...docs.map((doc) {
                    final data = doc.data();
                    final members = (data['members'] as List?)?.length ?? 0;
                    final emoji = data['emoji'] ?? '🔥';
                    final name = data['name'] ?? 'Circle';
                    final code = data['inviteCode'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            '$members members • Code: $code',
                            style: TextStyle(color: subTextColor, fontSize: 13),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () => _openCircleDetail(doc.id),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CircleDetailScreen extends StatelessWidget {
  final String circleId;
  const CircleDetailScreen({super.key, required this.circleId});

  void _showDeleteCircleConfirmation(BuildContext context, CircleService circleService, String circleName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Circle'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$circleName"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await circleService.deleteCircle(circleId);
                if (context.mounted) {
                  AppToast.show(
                    context,
                    message: 'Circle "$circleName" deleted.',
                    icon: Icons.delete_outline_rounded,
                    backgroundColor: const Color(0xFF991B1B),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, '$e'.replaceAll('Exception: ', ''));
                }
              }
            },
            child: const Text('Delete Circle'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, CircleService circleService, String mUid, String mName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Member'),
        content: Text('Remove $mName from this circle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await circleService.removeMember(circleId: circleId, targetUid: mUid);
                if (context.mounted) {
                  AppToast.info(context, '$mName removed from circle.');
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, '$e');
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleService = CircleService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F1218) : const Color(0xFFF9FAFC);
    final cardBg = isDark ? const Color(0xFF181C26) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            tooltip: 'Leave Circle',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Leave Circle'),
                  content: const Text('Are you sure you want to leave this circle?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await circleService.leaveCircle(circleId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: circleService.streamCircle(circleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: Text('Circle not found or deleted'));
          }

          final name = data['name'] ?? 'Circle';
          final emoji = data['emoji'] ?? '🔥';
          final desc = data['description'] ?? '';
          final code = data['inviteCode'] ?? '';
          final createdBy = data['createdBy'] ?? '';
          final List membersList = data['members'] ?? [];
          final Map<String, dynamic> memberDetails =
              Map<String, dynamic>.from(data['memberDetails'] ?? {});
          final currentUid = circleService.currentUid;
          final bool isAdmin = createdBy == currentUid;
          // Can delete only if admin AND no other members exist
          final bool canDelete = isAdmin && membersList.length <= 1;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Circle Hero Header
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D3139) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Invite Code Pill (Tap to Copy)
              Center(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    AppToast.show(
                      context,
                      message: 'Invite code $code copied!',
                      icon: Icons.copy_rounded,
                      backgroundColor: const Color(0xFF1E293B),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          'Invite Code: $code',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Member Accountability Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Members (${memberDetails.length})',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (isAdmin && membersList.length > 1)
                    Text(
                      'Remove members to delete circle',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              ...memberDetails.entries.map((entry) {
                final member = Map<String, dynamic>.from(entry.value);
                final mUid = entry.key;
                final mName = member['name'] ?? 'Friend';
                final mAvatar = member['avatar'] as String?;
                final isSelf = mUid == currentUid;
                final isMemberAdmin = mUid == createdBy;
                final completed = member['habitsDoneToday'] ?? 0;
                final total = member['totalHabits'] ?? 0;
                final allDone = completed > 0 && completed == total;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      MemberAvatar(
                        uid: mUid,
                        fallbackName: mName,
                        cachedAvatar: mAvatar,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isSelf ? '$mName (You)' : mName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                if (isMemberAdmin) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2D3139) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Admin',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              total == 0
                                  ? 'No habits logged today'
                                  : (allDone ? '🎉 All $total habits done!' : '$completed of $total completed'),
                              style: TextStyle(
                                fontSize: 12,
                                color: allDone ? const Color(0xFF10B981) : subTextColor,
                                fontWeight: allDone ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSelf) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allDone
                                ? Colors.grey.withValues(alpha: 0.2)
                                : const Color(0xFFFF6B6B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Text(allDone ? '👏' : '⚡', style: const TextStyle(fontSize: 14)),
                          label: Text(
                            allDone ? 'Cheer' : 'Nudge',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: allDone ? (isDark ? Colors.white70 : Colors.black87) : Colors.white,
                            ),
                          ),
                          onPressed: () async {
                            await circleService.sendNudge(
                              circleId: circleId,
                              targetUid: mUid,
                              targetName: mName,
                            );
                            if (context.mounted) {
                              AppToast.show(
                                context,
                                message: allDone ? 'Cheered $mName! 🎉' : 'Nudge sent to $mName! ⚡',
                                icon: allDone ? Icons.celebration_rounded : Icons.bolt_rounded,
                                backgroundColor: allDone ? const Color(0xFF166534) : const Color(0xFF991B1B),
                              );
                            }
                          },
                        ),
                        // Admin remove button
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                            tooltip: 'Remove from circle',
                            onPressed: () => _confirmRemoveMember(context, circleService, mUid, mName),
                          ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 28),

              // Delete Circle Button (Visible only to Admin)
              if (isAdmin)
                Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: canDelete ? Colors.redAccent : Colors.grey,
                      side: BorderSide(
                        color: canDelete ? Colors.redAccent : Colors.grey.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_forever_rounded, size: 20),
                    label: Text(
                      canDelete ? 'Delete Circle' : 'Delete Circle (Remove members first)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: canDelete
                        ? () => _showDeleteCircleConfirmation(context, circleService, name)
                        : () {
                            AppToast.info(context, 'Remove all members first before deleting this circle.');
                          },
                  ),
                ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
