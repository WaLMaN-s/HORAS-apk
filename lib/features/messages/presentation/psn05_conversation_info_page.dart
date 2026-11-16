import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide Block;
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/messages/presentation/messages_controller.dart';
import 'package:material_ui/material_ui.dart';

/// PSN-05 Info Percakapan (`PSN-R5`, `PSN-R6`).
class Psn05ConversationInfoPage extends ConsumerStatefulWidget {
  const Psn05ConversationInfoPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<Psn05ConversationInfoPage> createState() =>
      _Psn05ConversationInfoPageState();
}

class _Psn05ConversationInfoPageState
    extends ConsumerState<Psn05ConversationInfoPage> {
  Conversation? _conv;
  bool _isAdmin = false;
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (widget.conversationId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final chatRepo = ref.read(chatRepositoryProvider);
    final res = await chatRepo.getConversationById(widget.conversationId);
    if (!mounted) return;
    if (res is Err<Conversation>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    final isAdmin = await chatRepo.isGroupAdmin(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _conv = (res as Ok<Conversation>).value;
      _isAdmin = isAdmin;
      _isLoading = false;
    });
  }

  Future<void> _mute(MuteDurationOption duration) async {
    final conv = _conv;
    if (conv == null) return;
    final res = await ref
        .read(chatRepositoryProvider)
        .muteConversation(conversationId: conv.id, duration: duration);
    if (!mounted) return;
    if (res is Ok<Conversation>) {
      setState(() => _conv = res.value);
      AppToast.show(
        context,
        message: AppStrings.psn05MutedActiveToast,
        variant: AppToastVariant.success,
      );
    }
  }

  Future<void> _unmute() async {
    final conv = _conv;
    if (conv == null) return;
    final res = await ref
        .read(chatRepositoryProvider)
        .unmuteConversation(conv.id);
    if (!mounted) return;
    if (res is Ok<Conversation>) {
      setState(() => _conv = res.value);
      AppToast.show(
        context,
        message: AppStrings.psn05UnmutedToast,
        variant: AppToastVariant.info,
      );
    }
  }

  Future<void> _leaveGroup() async {
    final conv = _conv;
    if (conv == null) return;
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.psn05LeaveGroupTitle,
      message: AppStrings.psn05LeaveGroupBody,
      confirmLabel: AppStrings.psn05LeaveGroupBtn,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;

    final res = await ref
        .read(chatRepositoryProvider)
        .leaveGroupConversation(conv.id);
    if (!mounted) return;
    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await ref.read(conversationsListProvider.notifier).loadInitial();
    if (!mounted) return;
    context.pop('left');
  }

  Future<void> _blockDirectUser(PersonSummary other) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.sek04BlockConfirmTitle,
      message: AppStrings.sek04BlockConfirmBody,
      confirmLabel: AppStrings.psn03MenuBlock,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    final res = await ref.read(blockRepositoryProvider).blockUser(other.id);
    if (!mounted) return;
    if (res is Err<Block>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await ref.read(conversationsListProvider.notifier).loadInitial();
    if (!mounted) return;
    context.pop('blocked');
  }

  String _muteLabel(MuteDurationOption option) {
    return switch (option) {
      MuteDurationOption.oneHour => AppStrings.psn05Mute1Hour,
      MuteDurationOption.eightHours => AppStrings.psn05Mute8Hours,
      MuteDurationOption.oneWeek => AppStrings.psn05Mute1Week,
      MuteDurationOption.forever => AppStrings.psn05MuteForever,
    };
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authRepositoryProvider).currentUserId;
    final now = ref.read(authRepositoryProvider).currentTime;
    final colors = context.colors;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_conv == null) {
      body = StateView.empty(
        message: AppStrings.stateEmptyDefaultTitle,
        actionLabel: AppStrings.semanticsBack,
        onAction: () => context.pop(),
      );
    } else {
      final conv = _conv!;
      final isMuted = conv.mutedUntil != null && conv.mutedUntil!.isAfter(now);
      final isDirect = conv.type == ConversationType.direct;
      final other = isDirect
          ? conv.participants.where((p) => p.id != uid).firstOrNull
          : null;

      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(conv.title, style: context.typo.h2),
          const SizedBox(height: AppSpacing.lg),

          const SectionHeader(title: AppStrings.psn05MuteSection),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ...MuteDurationOption.values.map(
                (opt) =>
                    AppChip(label: _muteLabel(opt), onTap: () => _mute(opt)),
              ),
              if (isMuted)
                AppChip(
                  label: AppStrings.psn05UnmuteBtn,
                  isSelected: true,
                  onTap: _unmute,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: AppStrings.psn05MembersSection),
          const SizedBox(height: AppSpacing.sm),
          ...conv.participants.map(
            (member) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                onTap: member.displayName == AppStrings.psn03DeletedUserLabel
                    ? null
                    : () => context
                          .push(
                            '${AppPages.sek04.routePath}?userId=${member.id}',
                          )
                          .ignore(),
                leading: AppAvatar(
                  name: member.displayName,
                  seed: member.avatarSeed,
                ),
                title: Text(
                  '${member.displayName} · ${member.marga}',
                  style: context.typo.bodyStrong,
                ),
                subtitle: member.partuturan != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: PartuturanBadge(result: member.partuturan!),
                        ),
                      )
                    : null,
                trailing: !isDirect && _isAdmin && member.id != uid
                    ? IconButton(
                        tooltip: AppStrings.psn04AdminKickMemberAction,
                        icon: Icon(
                          Icons.person_remove_outlined,
                          color: colors.danger,
                        ),
                        onPressed: () async {
                          final ok = await ConfirmDialog.show(
                            context,
                            title: AppStrings.psn04AdminKickConfirmTitle,
                            message: AppStrings.psn04AdminKickConfirmBody,
                            confirmLabel: AppStrings.psn04AdminKickMemberAction,
                            isDestructive: true,
                          );
                          if (ok != true || !mounted) return;
                          await ref
                              .read(chatRepositoryProvider)
                              .removeGroupMember(
                                conversationId: conv.id,
                                targetUserId: member.id,
                              );
                          await _load();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (!isDirect) ...<Widget>[
            AppButton(
              label: AppStrings.psn05LeaveGroupBtn,
              variant: AppButtonVariant.secondary,
              isDestructive: true,
              isExpanded: true,
              onPressed: _leaveGroup,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: AppStrings.psn03MenuReport,
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            leadingIcon: Icons.flag_outlined,
            onPressed: () => context
                .push(
                  '/report?targetType=${isDirect ? 'user' : 'community'}&targetId=${other?.id ?? conv.communityId ?? conv.id}',
                )
                .ignore(),
          ),
          if (isDirect && other != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: AppStrings.psn03MenuBlock,
              variant: AppButtonVariant.secondary,
              isDestructive: true,
              isExpanded: true,
              leadingIcon: Icons.block_rounded,
              onPressed: () => _blockDirectUser(other),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.psn05Title)),
      body: SafeArea(child: body),
    );
  }
}
