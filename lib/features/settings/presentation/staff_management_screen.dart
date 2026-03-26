import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/shop_provider.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});
  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final shopId = ref.read(shopProvider).currentShopId ?? 1;
    try {
      final members = await api.get('/shop-members?shopId=$shopId');
      final roles = await api.get('/shop-roles?shopId=$shopId');
      if (!mounted) return;
      setState(() {
        _members = (members as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _roles = (roles as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _inviteMember() async {
    final usernameCtrl = TextEditingController();
    int? selectedRoleId;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Thêm nhân viên'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username', hintText: 'Nhập tên đăng nhập', prefixIcon: Icon(Icons.person_search))),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: selectedRoleId,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: _roles.map((r) => DropdownMenuItem<int>(value: r['id'] as int, child: Text(r['name'] as String))).toList(),
              onChanged: (v) => setDlg(() => selectedRoleId = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Thêm')),
          ],
        ),
      ),
    );

    if (result == true && usernameCtrl.text.trim().isNotEmpty) {
      final api = ref.read(apiClientProvider);
      final shopId = ref.read(shopProvider).currentShopId ?? 1;
      try {
        await api.post('/shop-members/invite?shopId=$shopId', data: {
          'username': usernameCtrl.text.trim(),
          'roleId': selectedRoleId,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm nhân viên và gửi thông báo'), backgroundColor: AppColors.success));
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member) async {
    int? selectedRoleId = (member['role'] as Map?)?['id'] as int?;
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Đổi vai trò - ${member['fullName'] ?? member['username']}'),
          content: DropdownButtonFormField<int>(
            initialValue: selectedRoleId,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: _roles.map((r) => DropdownMenuItem<int>(value: r['id'] as int, child: Text(r['name'] as String))).toList(),
            onChanged: (v) => setDlg(() => selectedRoleId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, selectedRoleId), child: const Text('Lưu')),
          ],
        ),
      ),
    );

    if (result != null) {
      final api = ref.read(apiClientProvider);
      try {
        await api.put('/shop-members/${member['id']}/role', data: {'roleId': result});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vai trò'), backgroundColor: AppColors.success));
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhân viên'),
        content: Text('Xóa "${member['fullName'] ?? member['username']}" khỏi shop?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final api = ref.read(apiClientProvider);
      try {
        await api.delete('/shop-members/${member['id']}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa nhân viên'), backgroundColor: AppColors.success));
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
        actions: [
          IconButton(icon: const Icon(Icons.group_add), tooltip: 'Quản lý vai trò', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleConfigScreen()))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _inviteMember,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 64, color: c.textMuted),
                  const SizedBox(height: 12),
                  Text('Chưa có nhân viên nào', style: TextStyle(color: c.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Nhấn "Thêm" để mời nhân viên', style: TextStyle(color: c.textMuted, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildMemberCard(_members[i], c),
                  ),
                ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m, AppThemeColors c) {
    final isOwner = m['memberType'] == 'OWNER';
    final roleName = isOwner ? 'Chủ shop' : ((m['role'] as Map?)?['name'] ?? 'Chưa gán role');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: isOwner ? AppColors.primary.withValues(alpha: 0.15) : c.surface,
          child: Icon(isOwner ? Icons.star : Icons.person, color: isOwner ? AppColors.primary : c.textSecondary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['fullName'] ?? m['username'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text('@${m['username'] ?? ''}', style: TextStyle(fontSize: 12, color: c.textMuted)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isOwner ? AppColors.primary.withValues(alpha: 0.1) : AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(roleName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isOwner ? AppColors.primary : AppColors.info)),
          ),
        ])),
        if (!isOwner) ...[
          IconButton(icon: const Icon(Icons.swap_horiz, size: 20), tooltip: 'Đổi vai trò', onPressed: () => _changeRole(m), color: AppColors.primary),
          IconButton(icon: const Icon(Icons.person_remove, size: 20), tooltip: 'Xóa', onPressed: () => _removeMember(m), color: AppColors.danger),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════
// Role Config Screen — create/edit roles + permissions
// ═══════════════════════════════════════════════════

const _permissionKeys = {
  'pos': 'Bán hàng (POS)',
  'sales_view': 'Xem đơn hàng',
  'products': 'Sản phẩm',
  'inventory': 'Kho hàng',
  'customers': 'Khách hàng',
  'suppliers': 'Nhà cung cấp',
  'finance': 'Tài chính',
  'settings': 'Cài đặt',
};

const _permissionLevels = ['none', 'view', 'edit', 'full'];
const _permissionLabels = {'none': 'Không', 'view': 'Xem', 'edit': 'Chỉnh sửa', 'full': 'Toàn quyền'};

class RoleConfigScreen extends ConsumerStatefulWidget {
  const RoleConfigScreen({super.key});
  @override
  ConsumerState<RoleConfigScreen> createState() => _RoleConfigScreenState();
}

class _RoleConfigScreenState extends ConsumerState<RoleConfigScreen> {
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final shopId = ref.read(shopProvider).currentShopId ?? 1;
    try {
      final data = await api.get('/shop-roles?shopId=$shopId');
      if (!mounted) return;
      setState(() {
        _roles = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showRoleEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    Map<String, String> perms = {};
    if (existing != null) {
      final raw = existing['permissions'];
      if (raw is String) {
        try {
          (Map<String, dynamic>.from(Map.castFrom(
            // ignore: avoid_dynamic_calls
            (raw.startsWith('{') ? _parseJson(raw) : {}) as Map,
          ))).forEach((k, v) => perms[k] = v.toString());
        } catch (_) {}
      } else if (raw is Map) {
        raw.forEach((k, v) => perms[k.toString()] = v.toString());
      }
    }
    // Ensure all keys exist
    for (final key in _permissionKeys.keys) {
      perms.putIfAbsent(key, () => 'none');
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Tạo vai trò mới' : 'Sửa vai trò'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên vai trò', hintText: 'VD: Thu ngân, Thủ kho')),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Phân quyền:', style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              ...(_permissionKeys.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
                  ToggleButtons(
                    isSelected: _permissionLevels.map((l) => perms[e.key] == l).toList(),
                    onPressed: (idx) => setDlg(() => perms[e.key] = _permissionLevels[idx]),
                    borderRadius: BorderRadius.circular(8),
                    constraints: const BoxConstraints(minWidth: 60, minHeight: 32),
                    textStyle: const TextStyle(fontSize: 11),
                    children: _permissionLevels.map((l) => Text(_permissionLabels[l]!)).toList(),
                  ),
                ]),
              ))),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final api = ref.read(apiClientProvider);
      final shopId = ref.read(shopProvider).currentShopId ?? 1;
      try {
        if (existing == null) {
          await api.post('/shop-roles?shopId=$shopId', data: {'name': nameCtrl.text.trim(), 'permissions': perms});
        } else {
          await api.put('/shop-roles/${existing['id']}', data: {'name': nameCtrl.text.trim(), 'permissions': perms});
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Đã tạo vai trò' : 'Đã cập nhật'), backgroundColor: AppColors.success));
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _deleteRole(Map<String, dynamic> role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa vai trò'),
        content: Text('Xóa vai trò "${role['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm == true) {
      final api = ref.read(apiClientProvider);
      try {
        await api.delete('/shop-roles/${role['id']}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa'), backgroundColor: AppColors.success));
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  dynamic _parseJson(String s) {
    try { return Uri.decodeFull(s); } catch (_) { return {}; }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý vai trò')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Tạo vai trò'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _roles.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 64, color: c.textMuted),
                  const SizedBox(height: 12),
                  Text('Chưa có vai trò nào', style: TextStyle(color: c.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tạo vai trò để phân quyền nhân viên', style: TextStyle(color: c.textMuted, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _roles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildRoleCard(_roles[i], c),
                  ),
                ),
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role, AppThemeColors c) {
    // Parse permissions for display
    Map<String, String> perms = {};
    final raw = role['permissions'];
    if (raw is String) {
      try { Map<String, dynamic>.from(Map.castFrom((raw.startsWith('{') ? _parseJson(raw) : {}) as Map)).forEach((k, v) => perms[k] = v.toString()); } catch (_) {}
    } else if (raw is Map) {
      raw.forEach((k, v) => perms[k.toString()] = v.toString());
    }

    final activePerms = perms.entries.where((e) => e.value != 'none').toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(role['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showRoleEditor(existing: role), color: AppColors.primary),
          IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => _deleteRole(role), color: AppColors.danger),
        ]),
        if (activePerms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: activePerms.map((e) {
            final label = _permissionKeys[e.key] ?? e.key;
            final level = _permissionLabels[e.value] ?? e.value;
            final isFull = e.value == 'full';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isFull ? AppColors.success.withValues(alpha: 0.1) : AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$label: $level', style: TextStyle(fontSize: 10, color: isFull ? AppColors.success : AppColors.info, fontWeight: FontWeight.w500)),
            );
          }).toList()),
        ],
      ]),
    );
  }
}
