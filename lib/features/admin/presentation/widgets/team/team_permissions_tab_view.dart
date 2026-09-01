import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/repositories/user_repository.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_state.dart';

class TeamPermissionsTabView extends StatefulWidget {
  final LeadsState state;
  final bool isDesktop;
  final bool isMobile;

  const TeamPermissionsTabView({
    super.key,
    required this.state,
    required this.isDesktop,
    required this.isMobile,
  });

  @override
  State<TeamPermissionsTabView> createState() =>
      _TeamPermissionsTabViewState();
}

class _TeamPermissionsTabViewState extends State<TeamPermissionsTabView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'full', 'standard', 'reassign', 'restricted'
  bool _isTableView = true; // List View first by default as requested

  static final Map<String, Map<String, dynamic>> _persistedPermissionsCache =
      {};
  final Map<String, Map<String, dynamic>> _agentPermissionsState = {};
  final Set<String> _savingPermissionAgentIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _toBool(dynamic val, {bool defaultValue = false}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) {
      final s = val.toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return defaultValue;
  }

  Map<String, dynamic> _getAgentPermissions(Map<String, dynamic> agent) {
    final agentId = agent['_id']?.toString() ?? '';
    if (agentId.isNotEmpty &&
        _persistedPermissionsCache.containsKey(agentId)) {
      return _persistedPermissionsCache[agentId]!;
    }
    if (_agentPermissionsState.containsKey(agentId)) {
      return _agentPermissionsState[agentId]!;
    }
    dynamic raw = agent['permissions'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {}
    }
    if (raw is Map) {
      final leadMap = raw['lead'] is Map
          ? Map<String, dynamic>.from(raw['lead'])
          : (raw['leads'] is Map
              ? Map<String, dynamic>.from(raw['leads'])
              : <String, dynamic>{});
      final dealerMap = raw['dealer'] is Map
          ? Map<String, dynamic>.from(raw['dealer'])
          : (raw['dealers'] is Map
              ? Map<String, dynamic>.from(raw['dealers'])
              : <String, dynamic>{});
      final perms = {
        'lead': {
          'create': _toBool(leadMap['create'], defaultValue: true),
          'update': _toBool(leadMap['update'], defaultValue: true),
          'reassign': _toBool(leadMap['reassign'], defaultValue: false),
          'delete': _toBool(leadMap['delete'], defaultValue: true),
        },
        'dealer': {
          'create': _toBool(dealerMap['create'], defaultValue: true),
          'update': _toBool(dealerMap['update'], defaultValue: true),
          'reassign': _toBool(dealerMap['reassign'], defaultValue: false),
          'delete': _toBool(dealerMap['delete'], defaultValue: true),
        }
      };
      if (agentId.isNotEmpty) {
        _persistedPermissionsCache[agentId] = perms;
      }
      return perms;
    }
    final defaultPerms = {
      'lead': {
        'create': true,
        'update': true,
        'reassign': false,
        'delete': true,
      },
      'dealer': {
        'create': true,
        'update': true,
        'reassign': false,
        'delete': true,
      }
    };
    if (agentId.isNotEmpty) {
      _persistedPermissionsCache[agentId] = defaultPerms;
    }
    return defaultPerms;
  }

  Future<void> _toggleAgentPermission(
    Map<String, dynamic> agent,
    String module,
    String action,
    bool newValue,
  ) async {
    final agentId = agent['_id']?.toString() ?? '';
    if (agentId.isEmpty) return;

    final currentPerms = _getAgentPermissions(agent);
    final updatedPerms = {
      'lead': Map<String, dynamic>.from(currentPerms['lead'] ?? {}),
      'dealer': Map<String, dynamic>.from(currentPerms['dealer'] ?? {}),
    };
    updatedPerms[module]?[action] = newValue;

    setState(() {
      _persistedPermissionsCache[agentId] = updatedPerms;
      _agentPermissionsState[agentId] = updatedPerms;
      agent['permissions'] = updatedPerms;
      _savingPermissionAgentIds.add(agentId);
    });

    try {
      var res = await ApiClient().put('/users/$agentId', {
        'permissions': updatedPerms,
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        res = await ApiClient().put('/users/sales/$agentId', {
          'permissions': updatedPerms,
        });
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _persistedPermissionsCache[agentId] = updatedPerms;
        agent['permissions'] = updatedPerms;
        UserRepository().invalidateCache();
        if (AuthService().currentUserId == agentId) {
          AuthService().updatePermissions(updatedPerms);
        }

        final agentName =
            '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
        final actionDisplay = action[0].toUpperCase() + action.substring(1);
        final moduleDisplay = module[0].toUpperCase() + module.substring(1);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    newValue
                        ? Icons.check_circle_outline
                        : Icons.remove_circle_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$moduleDisplay $actionDisplay ${newValue ? 'granted to' : 'revoked from'} $agentName',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor:
                  newValue ? AppTheme.primaryColor : const Color(0xFF334155),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        throw Exception('Server returned status ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _persistedPermissionsCache[agentId] = currentPerms;
        _agentPermissionsState[agentId] = currentPerms;
        agent['permissions'] = currentPerms;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update permission: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingPermissionAgentIds.remove(agentId);
        });
      }
    }
  }

  Future<void> _applyModuleBatch(
    Map<String, dynamic> agent,
    String module,
    bool enableAll,
  ) async {
    final agentId = agent['_id']?.toString() ?? '';
    if (agentId.isEmpty) return;

    final currentPerms = _getAgentPermissions(agent);
    final updatedPerms = {
      'lead': Map<String, dynamic>.from(currentPerms['lead'] ?? {}),
      'dealer': Map<String, dynamic>.from(currentPerms['dealer'] ?? {}),
    };
    updatedPerms[module] = {
      'create': enableAll,
      'update': enableAll,
      'reassign': enableAll,
      'delete': enableAll,
    };

    setState(() {
      _persistedPermissionsCache[agentId] = updatedPerms;
      _agentPermissionsState[agentId] = updatedPerms;
      agent['permissions'] = updatedPerms;
      _savingPermissionAgentIds.add(agentId);
    });

    try {
      var res = await ApiClient().put('/users/$agentId', {
        'permissions': updatedPerms,
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        res = await ApiClient().put('/users/sales/$agentId', {
          'permissions': updatedPerms,
        });
      }
      if (res.statusCode == 200 || res.statusCode == 201) {
        _persistedPermissionsCache[agentId] = updatedPerms;
        agent['permissions'] = updatedPerms;
        UserRepository().invalidateCache();
        if (AuthService().currentUserId == agentId) {
          AuthService().updatePermissions(updatedPerms);
        }
      }
    } catch (_) {
      setState(() {
        _persistedPermissionsCache[agentId] = currentPerms;
        _agentPermissionsState[agentId] = currentPerms;
        agent['permissions'] = currentPerms;
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPermissionAgentIds.remove(agentId);
        });
      }
    }
  }

  Future<void> _applyPermissionPreset(
    Map<String, dynamic> agent,
    String presetType,
  ) async {
    final agentId = agent['_id']?.toString() ?? '';
    if (agentId.isEmpty) return;

    final Map<String, dynamic> updatedPerms;
    if (presetType == 'full') {
      updatedPerms = {
        'lead': {
          'create': true,
          'update': true,
          'reassign': true,
          'delete': true,
        },
        'dealer': {
          'create': true,
          'update': true,
          'reassign': true,
          'delete': true,
        },
      };
    } else if (presetType == 'standard') {
      updatedPerms = {
        'lead': {
          'create': true,
          'update': true,
          'reassign': false,
          'delete': true,
        },
        'dealer': {
          'create': true,
          'update': true,
          'reassign': false,
          'delete': true,
        },
      };
    } else {
      updatedPerms = {
        'lead': {
          'create': false,
          'update': false,
          'reassign': false,
          'delete': false,
        },
        'dealer': {
          'create': false,
          'update': false,
          'reassign': false,
          'delete': false,
        },
      };
    }

    final currentPerms = _getAgentPermissions(agent);
    setState(() {
      _persistedPermissionsCache[agentId] = updatedPerms;
      _agentPermissionsState[agentId] = updatedPerms;
      agent['permissions'] = updatedPerms;
      _savingPermissionAgentIds.add(agentId);
    });

    try {
      var res = await ApiClient().put('/users/$agentId', {
        'permissions': updatedPerms,
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        res = await ApiClient().put('/users/sales/$agentId', {
          'permissions': updatedPerms,
        });
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        _persistedPermissionsCache[agentId] = updatedPerms;
        agent['permissions'] = updatedPerms;
        UserRepository().invalidateCache();
        if (AuthService().currentUserId == agentId) {
          AuthService().updatePermissions(updatedPerms);
        }

        final agentName =
            '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'.trim();
        final presetLabel = presetType == 'full'
            ? 'Full Access'
            : (presetType == 'standard'
                ? 'Standard Access'
                : 'Restricted Access');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Applied $presetLabel to $agentName',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Server error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _persistedPermissionsCache[agentId] = currentPerms;
        _agentPermissionsState[agentId] = currentPerms;
        agent['permissions'] = currentPerms;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply preset: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingPermissionAgentIds.remove(agentId);
        });
      }
    }
  }

  void _showWorkflowInfoModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F3820), AppTheme.primaryColor],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Role & Access Architecture',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGuideCard(
                  icon: Icons.add_circle_rounded,
                  color: const Color(0xFF10B981),
                  badge: 'ONBOARDING',
                  title: 'Create Permission',
                  desc:
                      'Permits agent to register new farmer leads or onboard verified shop dealers into the system.',
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  icon: Icons.edit_note_rounded,
                  color: const Color(0xFF0284C7),
                  badge: 'MUTATION',
                  title: 'Update Permission',
                  desc:
                      'Permits agent to edit prospect profiles, KYC records, contact numbers, and verified shop details.',
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFFD97706),
                  badge: 'REASSIGNMENT',
                  title: 'Reassign Permission (Transfers Out)',
                  desc:
                      'Allows transferring assigned leads or dealers to other sales teammates. Once transferred, the entity is removed from this agent’s active queue.',
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  icon: Icons.delete_sweep_rounded,
                  color: const Color(0xFFE11D48),
                  badge: 'DESTRUCTIVE',
                  title: 'Delete / Archive Permission',
                  desc:
                      'Allows archiving or soft-deleting non-viable leads or blocking dealer accounts.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            child: const Text('Dismiss Guide'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required Color color,
    required String badge,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Master-Level Sculpted Toggle Switch Capsule
  Widget _buildSculptedToggleCapsule({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
    Color activeColor = AppTheme.primaryColor,
    bool isReassign = false,
    bool isDestructive = false,
  }) {
    final finalColor = isDestructive
        ? const Color(0xFFE11D48)
        : (isReassign ? const Color(0xFFD97706) : activeColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!isEnabled),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isEnabled
                ? (isReassign
                    ? const Color(0xFFFFFBEB)
                    : (isDestructive
                        ? const Color(0xFFFFF1F2)
                        : finalColor.withValues(alpha: 0.06)))
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled
                  ? (isReassign
                      ? const Color(0xFFFCD34D)
                      : (isDestructive
                          ? const Color(0xFFFECDD3)
                          : finalColor.withValues(alpha: 0.3)))
                  : const Color(0xFFE2E8F0),
              width: isEnabled ? 1.2 : 1,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: finalColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? finalColor.withValues(alpha: 0.14)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isEnabled ? finalColor : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isEnabled
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isEnabled
                                  ? AppTheme.textPrimary
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isReassign && isEnabled) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFCD34D),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '⇄ Transfer',
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Transform.scale(
                scale: 0.65,
                child: Switch.adaptive(
                  value: isEnabled,
                  activeThumbColor: finalColor,
                  activeTrackColor: finalColor.withValues(alpha: 0.28),
                  inactiveThumbColor: const Color(0xFF94A3B8),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Interactive Micro Switch Capsule for the List/Table View
  Widget _buildListMicroToggleCapsule({
    required String label,
    required IconData icon,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
    Color activeColor = AppTheme.primaryColor,
    bool isReassign = false,
    bool isDestructive = false,
    required String tooltip,
  }) {
    final finalColor = isDestructive
        ? const Color(0xFFE11D48)
        : (isReassign ? const Color(0xFFD97706) : activeColor);

    return Tooltip(
      message: tooltip,
      textStyle: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!isEnabled),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              color: isEnabled
                  ? (isReassign
                      ? const Color(0xFFFEF3C7)
                      : (isDestructive
                          ? const Color(0xFFFFF1F2)
                          : finalColor.withValues(alpha: 0.08)))
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEnabled
                    ? (isReassign
                        ? const Color(0xFFFCD34D)
                        : (isDestructive
                            ? const Color(0xFFFECDD3)
                            : finalColor.withValues(alpha: 0.35)))
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isEnabled ? finalColor : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: isEnabled ? FontWeight.w700 : FontWeight.w500,
                    color: isEnabled
                        ? (isReassign
                            ? const Color(0xFF92400E)
                            : (isDestructive
                                ? const Color(0xFF9F1239)
                                : AppTheme.textPrimary))
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 2),
                Transform.scale(
                  scale: 0.58,
                  child: Switch.adaptive(
                    value: isEnabled,
                    activeThumbColor: finalColor,
                    activeTrackColor: finalColor.withValues(alpha: 0.3),
                    inactiveThumbColor: const Color(0xFF94A3B8),
                    inactiveTrackColor: const Color(0xFFE2E8F0),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSalesAgents = (widget.state.salesAgents.isNotEmpty)
        ? widget.state.salesAgents
        : widget.state.allRawUsers
            .where((u) => u['role'] == 'sales')
            .toList();

    int fullAccessCount = 0;
    int standardCount = 0;
    int reassignCount = 0;
    int restrictedCount = 0;

    for (final agent in allSalesAgents) {
      final perms = _getAgentPermissions(agent);
      final lp = perms['lead'] ?? {};
      final dp = perms['dealer'] ?? {};
      int active = 0;
      if (lp['create'] == true) active++;
      if (lp['update'] == true) active++;
      if (lp['reassign'] == true) active++;
      if (lp['delete'] == true) active++;
      if (dp['create'] == true) active++;
      if (dp['update'] == true) active++;
      if (dp['reassign'] == true) active++;
      if (dp['delete'] == true) active++;

      if (active == 8) fullAccessCount++;
      if (active == 6 && lp['reassign'] != true && dp['reassign'] != true) {
        standardCount++;
      }
      if (lp['reassign'] == true || dp['reassign'] == true) reassignCount++;
      if (active <= 2) restrictedCount++;
    }

    final filteredAgents = allSalesAgents.where((agent) {
      final name =
          '${agent['firstName'] ?? ''} ${agent['lastName'] ?? ''}'
              .toLowerCase();
      final email = (agent['email'] ?? '').toLowerCase();
      final phone = (agent['phoneNumber'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          name.contains(query) || email.contains(query) || phone.contains(query);

      if (!matchesSearch) return false;

      final perms = _getAgentPermissions(agent);
      final lp = perms['lead'] ?? {};
      final dp = perms['dealer'] ?? {};
      int active = 0;
      if (lp['create'] == true) active++;
      if (lp['update'] == true) active++;
      if (lp['reassign'] == true) active++;
      if (lp['delete'] == true) active++;
      if (dp['create'] == true) active++;
      if (dp['update'] == true) active++;
      if (dp['reassign'] == true) active++;
      if (dp['delete'] == true) active++;

      if (_selectedFilter == 'full') return active == 8;
      if (_selectedFilter == 'standard') {
        return active == 6 && lp['reassign'] != true && dp['reassign'] != true;
      }
      if (_selectedFilter == 'reassign') {
        return lp['reassign'] == true || dp['reassign'] == true;
      }
      if (_selectedFilter == 'restricted') return active <= 2;

      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Pro Studio Command Header
        _buildStudioHeader(
          totalAgents: allSalesAgents.length,
          fullCount: fullAccessCount,
          standardCount: standardCount,
          reassignCount: reassignCount,
          restrictedCount: restrictedCount,
        ),
        const SizedBox(height: 14),

        // 2. Search & Segmented Filter Bar (With List First, Grid Second)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText:
                        'Search sales agents to configure authorization rules...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              if (widget.isDesktop) ...[
                const SizedBox(width: 12),
                _buildFilterPill('All (${allSalesAgents.length})', 'all'),
                const SizedBox(width: 6),
                _buildFilterPill('Full ($fullAccessCount)', 'full'),
                const SizedBox(width: 6),
                _buildFilterPill('Standard ($standardCount)', 'standard'),
                const SizedBox(width: 6),
                _buildFilterPill('Reassign ($reassignCount)', 'reassign'),
                const SizedBox(width: 6),
                _buildFilterPill('Restricted ($restrictedCount)', 'restricted'),
                const SizedBox(width: 14),
                // View Switcher: List View FIRST, Grid View SECOND
                Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _buildViewModeButton(
                        icon: Icons.table_rows_rounded,
                        tooltip: 'Advanced List View',
                        isSelected: _isTableView,
                        onTap: () => setState(() => _isTableView = true),
                      ),
                      _buildViewModeButton(
                        icon: Icons.grid_view_rounded,
                        tooltip: 'Pro Studio Grid View',
                        isSelected: !_isTableView,
                        onTap: () => setState(() => _isTableView = false),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Main Agent Permissions List / Matrix
        if (filteredAgents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 32,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No sales agents matching "$_searchQuery"'
                      : 'No agents match the selected authorization filter',
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try adjusting your search query or reset the filter pill above.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (widget.isDesktop && _isTableView)
          _buildAdvancedListMatrix(filteredAgents)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredAgents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final agent = filteredAgents[index];
              return _buildMasterAgentCard(agent);
            },
          ),
      ],
    );
  }

  // Master Studio Header Bar
  Widget _buildStudioHeader({
    required int totalAgents,
    required int fullCount,
    required int standardCount,
    required int reassignCount,
    required int restrictedCount,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D2818),
            Color(0xFF144D2B),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D2B).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -24,
            child: Icon(
              Icons.shield_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isDesktop ? 20 : 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Permissions & Role Governance',
                            style: GoogleFonts.outfit(
                              fontSize: widget.isMobile ? 14 : 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'LIVE SYNC',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF6EE7B7),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Granular Create, Update, Reassign & Delete controls for team sales agents.',
                        style: GoogleFonts.outfit(
                          fontSize: widget.isMobile ? 11 : 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isDesktop) ...[
                  const SizedBox(width: 16),
                  _buildStudioStatPill(
                    label: 'Agents',
                    value: '$totalAgents',
                    badgeColor: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 8),
                  _buildStudioStatPill(
                    label: 'Full Access',
                    value: '$fullCount',
                    badgeColor: const Color(0xFF34D399),
                  ),
                  const SizedBox(width: 8),
                  _buildStudioStatPill(
                    label: 'Standard',
                    value: '$standardCount',
                    badgeColor: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 8),
                  _buildStudioStatPill(
                    label: 'Reassign ⇄',
                    value: '$reassignCount',
                    badgeColor: const Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  tooltip: 'Permissions Workflow Guide',
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: _showWorkflowInfoModal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioStatPill({
    required String label,
    required String value,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String title, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // Next-Gen Advanced List View Matrix
  Widget _buildAdvancedListMatrix(List<Map<String, dynamic>> agents) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.7),
            1: FlexColumnWidth(3.8),
            2: FlexColumnWidth(3.8),
            3: FlexColumnWidth(1.7),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Master Table Header
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderColor, width: 1.2),
                ),
              ),
              children: [
                _buildHeaderCell(
                  'Sales Agent & Authority',
                  icon: Icons.person_outline_rounded,
                ),
                _buildHeaderCell(
                  'Leads Access (Prospects)',
                  icon: Icons.campaign_rounded,
                  accentColor: const Color(0xFF0284C7),
                ),
                _buildHeaderCell(
                  'Dealers Access (Verified Stores)',
                  icon: Icons.storefront_rounded,
                  accentColor: const Color(0xFF0D9488),
                ),
                _buildHeaderCell(
                  'Presets & Metrics',
                  icon: Icons.bolt_rounded,
                  alignRight: true,
                ),
              ],
            ),
            // Master Table Rows
            ...agents.asMap().entries.map((entry) {
              final index = entry.key;
              final agent = entry.value;
              final agentId = agent['_id']?.toString() ?? '';
              final firstName = agent['firstName'] ?? '';
              final lastName = agent['lastName'] ?? '';
              final name = '$firstName $lastName'.trim().isNotEmpty
                  ? '$firstName $lastName'.trim()
                  : (agent['name'] ?? 'Sales Agent');
              final email = agent['email'] ?? '-';
              final phone = agent['phoneNumber'] ?? '-';
              final initials = (name.isNotEmpty ? name[0] : 'S').toUpperCase();

              final perms = _getAgentPermissions(agent);
              final lp = perms['lead'] as Map<String, dynamic>? ?? {};
              final dp = perms['dealer'] as Map<String, dynamic>? ?? {};

              int activeCount = 0;
              if (lp['create'] == true) activeCount++;
              if (lp['update'] == true) activeCount++;
              if (lp['reassign'] == true) activeCount++;
              if (lp['delete'] == true) activeCount++;
              if (dp['create'] == true) activeCount++;
              if (dp['update'] == true) activeCount++;
              if (dp['reassign'] == true) activeCount++;
              if (dp['delete'] == true) activeCount++;

              final isSaving = _savingPermissionAgentIds.contains(agentId);
              final rowBgColor =
                  index.isOdd ? const Color(0xFFFAFBFC) : Colors.white;

              Color tierColor;
              String tierTag;
              if (activeCount == 8) {
                tierColor = const Color(0xFF10B981);
                tierTag = 'FULL';
              } else if (activeCount >= 6) {
                tierColor = const Color(0xFF0284C7);
                tierTag = 'STANDARD';
              } else if (activeCount > 0) {
                tierColor = const Color(0xFFD97706);
                tierTag = 'CUSTOM';
              } else {
                tierColor = const Color(0xFF64748B);
                tierTag = 'RESTRICTED';
              }

              return TableRow(
                decoration: BoxDecoration(
                  color: rowBgColor,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                children: [
                  // 1. Agent Identity Column
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                tierColor.withValues(alpha: 0.8),
                                tierColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tierColor.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tierColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      tierTag,
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: tierColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1.5),
                              Text(
                                '$email • $phone',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Leads Interactive Toggle Switches
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildListMicroToggleCapsule(
                          label: 'Create',
                          icon: Icons.add_circle_outline_rounded,
                          isEnabled: lp['create'] == true,
                          activeColor: const Color(0xFF10B981),
                          tooltip: 'Allow adding new farmer prospect leads',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'lead',
                            'create',
                            val,
                          ),
                        ),
                        _buildListMicroToggleCapsule(
                          label: 'Edit',
                          icon: Icons.edit_note_rounded,
                          isEnabled: lp['update'] == true,
                          activeColor: const Color(0xFF0284C7),
                          tooltip: 'Allow editing lead details & KYC status',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'lead',
                            'update',
                            val,
                          ),
                        ),
                        _buildListMicroToggleCapsule(
                          label: 'Reassign ⇄',
                          icon: Icons.swap_horiz_rounded,
                          isEnabled: lp['reassign'] == true,
                          isReassign: true,
                          tooltip:
                              'Allow transferring leads to teammates (removes from active queue)',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'lead',
                            'reassign',
                            val,
                          ),
                        ),
                        _buildListMicroToggleCapsule(
                          label: 'Delete',
                          icon: Icons.delete_outline_rounded,
                          isEnabled: lp['delete'] == true,
                          isDestructive: true,
                          tooltip: 'Allow archiving or soft-deleting leads',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'lead',
                            'delete',
                            val,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Dealers Interactive Toggle Switches
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildListMicroToggleCapsule(
                          label: 'Create',
                          icon: Icons.add_circle_outline_rounded,
                          isEnabled: dp['create'] == true,
                          activeColor: const Color(0xFF0D9488),
                          tooltip: 'Allow onboarding new verified store accounts',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'dealer',
                            'create',
                            val,
                          ),
                        ),
                        _buildListMicroToggleCapsule(
                          label: 'Edit',
                          icon: Icons.edit_note_rounded,
                          isEnabled: dp['update'] == true,
                          activeColor: const Color(0xFF0284C7),
                          tooltip: 'Allow updating store information & terms',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'dealer',
                            'update',
                            val,
                          ),
                        ),
                        _buildListMicroToggleCapsule(
                          label: 'Reassign ⇄',
                          icon: Icons.swap_horiz_rounded,
                          isEnabled: dp['reassign'] == true,
                          isReassign: true,
                          tooltip:
                              'Allow transferring dealers to teammates (removes from active queue)',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'dealer',
                            'reassign',
                            val,
                          ),
                        ),
                        _buildListMicroToggleCapsule(
                          label: 'Delete',
                          icon: Icons.delete_outline_rounded,
                          isEnabled: dp['delete'] == true,
                          isDestructive: true,
                          tooltip: 'Allow blocking or archiving dealer stores',
                          onChanged: (val) => _toggleAgentPermission(
                            agent,
                            'dealer',
                            'delete',
                            val,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Quick Presets & Status Metric
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isSaving)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: activeCount > 0
                                ? tierColor.withValues(alpha: 0.1)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: activeCount > 0
                                  ? tierColor.withValues(alpha: 0.3)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            '$activeCount/8',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: activeCount > 0
                                  ? tierColor
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildProfessionalPresetDropdown(
                          agent: agent,
                          activeCount: activeCount,
                          isStandard: activeCount == 6 &&
                              lp['reassign'] != true &&
                              dp['reassign'] != true,
                          levelColor: tierColor,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // Master Agent Card for Pro Studio Grid View
  Widget _buildMasterAgentCard(Map<String, dynamic> agent) {
    final agentId = agent['_id']?.toString() ?? '';
    final firstName = agent['firstName'] ?? '';
    final lastName = agent['lastName'] ?? '';
    final name = '$firstName $lastName'.trim().isNotEmpty
        ? '$firstName $lastName'.trim()
        : (agent['name'] ?? 'Sales Agent');
    final email = agent['email'] ?? '-';
    final phone = agent['phoneNumber'] ?? '-';
    final initials = (name.isNotEmpty ? name[0] : 'S').toUpperCase();

    final perms = _getAgentPermissions(agent);
    final lp = perms['lead'] as Map<String, dynamic>? ?? {};
    final dp = perms['dealer'] as Map<String, dynamic>? ?? {};

    int activeCount = 0;
    if (lp['create'] == true) activeCount++;
    if (lp['update'] == true) activeCount++;
    if (lp['reassign'] == true) activeCount++;
    if (lp['delete'] == true) activeCount++;
    if (dp['create'] == true) activeCount++;
    if (dp['update'] == true) activeCount++;
    if (dp['reassign'] == true) activeCount++;
    if (dp['delete'] == true) activeCount++;

    final isSaving = _savingPermissionAgentIds.contains(agentId);

    Color levelColor;
    String levelLabel;
    if (activeCount == 8) {
      levelColor = const Color(0xFF10B981);
      levelLabel = 'FULL ACCESS';
    } else if (activeCount >= 6) {
      levelColor = const Color(0xFF0284C7);
      levelLabel = 'STANDARD';
    } else if (activeCount > 0) {
      levelColor = const Color(0xFFD97706);
      levelLabel = 'CUSTOM';
    } else {
      levelColor = const Color(0xFF64748B);
      levelLabel = 'RESTRICTED';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeCount > 0
              ? levelColor.withValues(alpha: 0.25)
              : AppTheme.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: levelColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        levelColor.withValues(alpha: 0.8),
                        levelColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: levelColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: levelColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: levelColor.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              levelLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: levelColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        '$email • $phone',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (widget.isDesktop) ...[
                  _buildQuickPresetPill(
                    label: '⚡ Full (8)',
                    isSelected: activeCount == 8,
                    color: const Color(0xFF10B981),
                    onTap: () => _applyPermissionPreset(agent, 'full'),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPresetPill(
                    label: '✦ Standard',
                    isSelected: activeCount == 6 &&
                        lp['reassign'] != true &&
                        dp['reassign'] != true,
                    color: const Color(0xFF0284C7),
                    onTap: () => _applyPermissionPreset(agent, 'standard'),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPresetPill(
                    label: '🔒 Restrict',
                    isSelected: activeCount == 0,
                    color: const Color(0xFF64748B),
                    onTap: () => _applyPermissionPreset(agent, 'restricted'),
                  ),
                ] else
                  _buildProfessionalPresetDropdown(
                    agent: agent,
                    activeCount: activeCount,
                    isStandard: activeCount == 6 &&
                        lp['reassign'] != true &&
                        dp['reassign'] != true,
                    levelColor: levelColor,
                    isCompact: true,
                  ),
              ],
            ),
          ),

          // Two Side-By-Side Access Bays
          Padding(
            padding: const EdgeInsets.all(14),
            child: widget.isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildAccessBay(
                          bayTitle: 'Lead Management',
                          baySubtitle: 'PROSPECTS & FARMER LEADS',
                          icon: Icons.campaign_rounded,
                          accentColor: const Color(0xFF0284C7),
                          agent: agent,
                          moduleKey: 'lead',
                          perms: lp,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildAccessBay(
                          bayTitle: 'Dealer Management',
                          baySubtitle: 'VERIFIED STORES & DEALERS',
                          icon: Icons.storefront_rounded,
                          accentColor: const Color(0xFF0D9488),
                          agent: agent,
                          moduleKey: 'dealer',
                          perms: dp,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildAccessBay(
                        bayTitle: 'Lead Management',
                        baySubtitle: 'PROSPECTS & FARMER LEADS',
                        icon: Icons.campaign_rounded,
                        accentColor: const Color(0xFF0284C7),
                        agent: agent,
                        moduleKey: 'lead',
                        perms: lp,
                      ),
                      const SizedBox(height: 12),
                      _buildAccessBay(
                        bayTitle: 'Dealer Management',
                        baySubtitle: 'VERIFIED STORES & DEALERS',
                        icon: Icons.storefront_rounded,
                        accentColor: const Color(0xFF0D9488),
                        agent: agent,
                        moduleKey: 'dealer',
                        perms: dp,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetPill({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessBay({
    required String bayTitle,
    required String baySubtitle,
    required IconData icon,
    required Color accentColor,
    required Map<String, dynamic> agent,
    required String moduleKey,
    required Map<String, dynamic> perms,
  }) {
    final bool canCreate = perms['create'] == true;
    final bool canUpdate = perms['update'] == true;
    final bool canReassign = perms['reassign'] == true;
    final bool canDelete = perms['delete'] == true;

    final int moduleActive = (canCreate ? 1 : 0) +
        (canUpdate ? 1 : 0) +
        (canReassign ? 1 : 0) +
        (canDelete ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bayTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      baySubtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () =>
                    _applyModuleBatch(agent, moduleKey, moduleActive < 4),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    moduleActive < 4 ? 'Grant All' : 'Clear All',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 6,
            childAspectRatio: 3.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSculptedToggleCapsule(
                title: 'Create',
                subtitle: moduleKey == 'lead'
                    ? 'New prospect entry'
                    : 'New store onboard',
                icon: Icons.add_circle_rounded,
                isEnabled: canCreate,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) =>
                    _toggleAgentPermission(agent, moduleKey, 'create', val),
              ),
              _buildSculptedToggleCapsule(
                title: 'Update',
                subtitle: moduleKey == 'lead'
                    ? 'KYC & details edit'
                    : 'Store info edit',
                icon: Icons.edit_note_rounded,
                isEnabled: canUpdate,
                activeColor: const Color(0xFF0284C7),
                onChanged: (val) =>
                    _toggleAgentPermission(agent, moduleKey, 'update', val),
              ),
              _buildSculptedToggleCapsule(
                title: 'Reassign ⇄',
                subtitle: 'Team handover',
                icon: Icons.swap_horiz_rounded,
                isEnabled: canReassign,
                isReassign: true,
                onChanged: (val) =>
                    _toggleAgentPermission(agent, moduleKey, 'reassign', val),
              ),
              _buildSculptedToggleCapsule(
                title: 'Delete',
                subtitle: moduleKey == 'lead'
                    ? 'Trash archive'
                    : 'Block account',
                icon: Icons.delete_outline_rounded,
                isEnabled: canDelete,
                isDestructive: true,
                onChanged: (val) =>
                    _toggleAgentPermission(agent, moduleKey, 'delete', val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String text, {
    IconData? icon,
    Color? accentColor,
    bool alignRight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: accentColor ?? const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              text.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: accentColor ?? const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalPresetDropdown({
    required Map<String, dynamic> agent,
    required int activeCount,
    required bool isStandard,
    required Color levelColor,
    bool isCompact = false,
  }) {
    return PopupMenuButton<String>(
      onSelected: (val) => _applyPermissionPreset(agent, val),
      tooltip: 'Apply Role Template',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 13,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'QUICK ROLE TEMPLATES',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'full',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _buildPresetMenuItem(
            icon: Icons.bolt_rounded,
            badgeColor: const Color(0xFF10B981),
            title: 'Full Access (8/8)',
            desc: 'All 8 permissions enabled across Leads & Dealers',
            isSelected: activeCount == 8,
          ),
        ),
        PopupMenuItem<String>(
          value: 'standard',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _buildPresetMenuItem(
            icon: Icons.verified_user_rounded,
            badgeColor: const Color(0xFF0284C7),
            title: 'Standard Operations (6/8)',
            desc: 'Create, Edit & Delete. Reassignment locked.',
            isSelected: isStandard,
          ),
        ),
        PopupMenuItem<String>(
          value: 'restricted',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _buildPresetMenuItem(
            icon: Icons.lock_outline_rounded,
            badgeColor: const Color(0xFF64748B),
            title: 'Restricted Access (0/8)',
            desc: 'All mutation & transfer actions revoked.',
            isSelected: activeCount == 0,
          ),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 10,
              vertical: isCompact ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 13,
                  color: levelColor,
                ),
                const SizedBox(width: 5),
                Text(
                  'Preset',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetMenuItem({
    required IconData icon,
    required Color badgeColor,
    required String title,
    required String desc,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: badgeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: badgeColor,
            ),
        ],
      ),
    );
  }
}

