import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/utils/toast_service.dart';
import '../../settings/providers/shop_provider.dart';

List<Map<String, dynamic>> _normalizeMapList(dynamic raw) {
  final value = raw is List
      ? raw
      : raw is Map
      ? (raw['data'] ?? raw['items'] ?? (raw.isEmpty ? [] : raw))
      : [];
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (value is Map && value.isNotEmpty) {
    return [Map<String, dynamic>.from(value)];
  }
  return [];
}

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});
  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _pendingMembers = [];
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
      final membersRaw = await api.get('/shop-members?shopId=$shopId');
      final rolesRaw = await api.get('/shop-roles?shopId=$shopId');
      final pendingRaw = await api.get('/shop-members/pending?shopId=$shopId');
      if (!mounted) return;
      setState(() {
        _members = _normalizeMapList(membersRaw);
        _roles = _normalizeMapList(rolesRaw);
        _pendingMembers = _normalizeMapList(pendingRaw);
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
    bool isSubmitting = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = AppThemeColors.of(ctx);
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Thêm nhân viên',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: c.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: c.textPrimary,
                    ),
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Tên đăng nhập (đã có trên hệ thống) *',
                      hintText: 'VD: nhanvien01 (tài khoản đã đăng ký)',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: c.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lưu ý: Nhân viên cần tự đăng ký tài khoản trên ứng dụng trước khi được thêm vào cửa hàng.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: c.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedRoleId,
                    decoration: InputDecoration(
                      labelText: 'Vai trò *',
                      prefixIcon: Icon(
                        Icons.shield_outlined,
                        color: c.textMuted,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: c.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: c.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: c.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem<int>(
                            value: r['id'] as int,
                            child: Text(
                              r['name'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (v) => setDlg(() {
                            selectedRoleId = v;
                            errorMessage = null;
                          }),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: GoogleFonts.inter(
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(ctx, false),
                child: Text(
                  'Hủy',
                  style: GoogleFonts.outfit(
                    color: c.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (usernameCtrl.text.trim().isEmpty) {
                          ToastService.showError('Vui lòng nhập tên đăng nhập');
                          return;
                        }

                        setDlg(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        final api = ref.read(apiClientProvider);
                        final shopId =
                            ref.read(shopProvider).currentShopId ?? 1;

                        try {
                          await api.post(
                            '/shop-members/invite?shopId=$shopId',
                            data: {
                              'username': usernameCtrl.text.trim(),
                              'roleId': selectedRoleId,
                            },
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, true);
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setDlg(() {
                            isSubmitting = false;
                            errorMessage = e is ApiException
                                ? e.message
                                : 'Lỗi: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Thêm',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      if (!mounted) return;
      ToastService.showSuccess('Đã thêm nhân viên trực tiếp vào cửa hàng');
      _load();
    }
  }

  Future<void> _handlePendingDecision(
    Map<String, dynamic> member, {
    required bool approve,
  }) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: approve ? 'Phê duyệt yêu cầu' : 'Từ chối yêu cầu',
      message: approve
          ? 'Phê duyệt cho "${member['fullName'] ?? member['username']}" tham gia cửa hàng của bạn?'
          : 'Từ chối yêu cầu tham gia của "${member['fullName'] ?? member['username']}"?',
      confirmText: approve ? 'Duyệt' : 'Từ chối',
      cancelText: 'Hủy',
      isDestructive: !approve,
    );
    if (confirmed == true) {
      setState(() => _loading = true);
      final api = ref.read(apiClientProvider);
      final path =
          '/shop-members/${member['id']}/${approve ? 'approve' : 'reject'}';
      try {
        await api.post(path);
        if (!mounted) return;
        ToastService.showSuccess(
          approve
              ? 'Đã duyệt yêu cầu thành công'
              : 'Đã từ chối yêu cầu tham gia',
        );
        _load();
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ToastService.showError('Lỗi: $e');
      }
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member) async {
    int? selectedRoleId = (member['role'] as Map?)?['id'] as int?;
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        final c = AppThemeColors.of(ctx);
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Đổi vai trò - ${member['fullName'] ?? member['username']}',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: c.textPrimary,
              ),
            ),
            content: DropdownButtonFormField<int>(
              initialValue: selectedRoleId,
              decoration: InputDecoration(
                labelText: 'Vai trò',
                prefixIcon: Icon(
                  Icons.shield_outlined,
                  color: c.textMuted,
                  size: 20,
                ),
                filled: true,
                fillColor: c.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
              items: _roles
                  .map(
                    (r) => DropdownMenuItem<int>(
                      value: r['id'] as int,
                      child: Text(
                        r['name'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDlg(() => selectedRoleId = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Hủy',
                  style: GoogleFonts.outfit(
                    color: c.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selectedRoleId),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Lưu',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      final api = ref.read(apiClientProvider);
      setState(() => _loading = true);
      try {
        await api.put(
          '/shop-members/${member['id']}/role',
          data: {'roleId': result},
        );
        if (!mounted) return;
        ToastService.showSuccess('Đã cập nhật vai trò nhân viên thành công');
        _load();
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ToastService.showError('Lỗi: $e');
      }
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Xóa nhân viên',
      message:
          'Bạn chắc chắn muốn xóa "${member['fullName'] ?? member['username']}" khỏi cửa hàng?',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
      isDestructive: true,
    );
    if (confirmed == true) {
      setState(() => _loading = true);
      final api = ref.read(apiClientProvider);
      try {
        await api.delete('/shop-members/${member['id']}');
        if (!mounted) return;
        ToastService.showSuccess('Đã xóa nhân viên khỏi hệ thống');
        _load();
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ToastService.showError('Lỗi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Quản lý nhân viên',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: c.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.shield_outlined),
              tooltip: 'Quản lý vai trò',
              onPressed: () => context.push('/roles'),
            ),
          ],
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: c.textMuted,
            labelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'Nhân viên (${_members.length})'),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Chờ duyệt (${_pendingMembers.length})'),
                    if (_pendingMembers.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _inviteMember,
          icon: const Icon(Icons.person_add_rounded),
          label: Text(
            'Thêm nhân viên',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  // Tab 1: Active members
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _members.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 100),
                              AppEmpty(
                                message: 'Chưa có nhân viên nào',
                                subtitle:
                                    'Nhấn "Thêm nhân viên" để thêm trực tiếp',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _members.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _buildMemberCard(_members[i], c, theme),
                          ),
                  ),

                  // Tab 2: Pending requests
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _pendingMembers.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 100),
                              AppEmpty(
                                message: 'Không có yêu cầu chờ duyệt',
                                subtitle:
                                    'Nhân viên mới điền mã shop sẽ xuất hiện tại đây',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _pendingMembers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _buildPendingCard(_pendingMembers[i], c, theme),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMemberCard(
    Map<String, dynamic> m,
    AppThemeColors c,
    ThemeData theme,
  ) {
    final isOwner = m['memberType'] == 'OWNER';
    final roleName = isOwner
        ? 'Chủ shop'
        : ((m['role'] as Map?)?['name'] ?? 'Chưa gán role');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOwner
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : c.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              isOwner ? Icons.star_rounded : Icons.person_rounded,
              color: isOwner ? theme.colorScheme.primary : c.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['fullName'] ?? m['username'] ?? 'N/A',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${m['username'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isOwner
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roleName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOwner
                          ? theme.colorScheme.primary
                          : AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isOwner) ...[
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, size: 20),
              tooltip: 'Đổi vai trò',
              onPressed: () => _changeRole(m),
              color: theme.colorScheme.primary,
            ),
            IconButton(
              icon: const Icon(Icons.person_remove_rounded, size: 20),
              tooltip: 'Xóa',
              onPressed: () => _removeMember(m),
              color: AppColors.danger,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingCard(
    Map<String, dynamic> m,
    AppThemeColors c,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              (m['fullName']?.isNotEmpty == true
                      ? m['fullName'][0]
                      : (m['username']?.isNotEmpty == true
                            ? m['username'][0]
                            : '?'))
                  .toString()
                  .toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['fullName'] ?? m['username'] ?? 'N/A',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${m['username'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
                tooltip: 'Duyệt',
                onPressed: () => _handlePendingDecision(m, approve: true),
              ),
              IconButton(
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.danger,
                  size: 24,
                ),
                tooltip: 'Từ chối',
                onPressed: () => _handlePendingDecision(m, approve: false),
              ),
            ],
          ),
        ],
      ),
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
const _permissionLabels = {
  'none': 'Không',
  'view': 'Xem',
  'edit': 'Chỉnh sửa',
  'full': 'Toàn quyền',
};

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
        _roles = _normalizeMapList(data);
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
          (Map<String, dynamic>.from(
            Map.castFrom((raw.startsWith('{') ? _parseJson(raw) : {}) as Map),
          )).forEach((k, v) => perms[k] = v.toString());
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
      builder: (ctx) {
        final c = AppThemeColors.of(ctx);
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            final nameEmpty = nameCtrl.text.trim().isEmpty;
            return AlertDialog(
              backgroundColor: c.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                existing == null ? 'Tạo vai trò mới' : 'Sửa vai trò',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: c.textPrimary,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        onChanged: (_) => setDlg(() {}),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: c.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Tên vai trò *',
                          hintText: 'VD: Thu ngân, Thủ kho',
                          errorText: nameEmpty
                              ? 'Vui lòng nhập tên vai trò'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Phân quyền chi tiết:',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_permissionKeys.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ToggleButtons(
                                isSelected: _permissionLevels
                                    .map((l) => perms[e.key] == l)
                                    .toList(),
                                onPressed: (idx) => setDlg(
                                  () => perms[e.key] = _permissionLevels[idx],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                selectedColor: Colors.white,
                                fillColor: theme.colorScheme.primary,
                                color: c.textSecondary,
                                constraints: const BoxConstraints(
                                  minWidth: 50,
                                  minHeight: 30,
                                ),
                                textStyle: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: _permissionLevels
                                    .map((l) => Text(_permissionLabels[l]!))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Hủy',
                    style: GoogleFonts.outfit(
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: nameEmpty ? null : () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Lưu',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final api = ref.read(apiClientProvider);
      final shopId = ref.read(shopProvider).currentShopId ?? 1;
      setState(() => _loading = true);
      try {
        if (existing == null) {
          await api.post(
            '/shop-roles?shopId=$shopId',
            data: {'name': nameCtrl.text.trim(), 'permissions': perms},
          );
        } else {
          await api.put(
            '/shop-roles/${existing['id']}',
            data: {'name': nameCtrl.text.trim(), 'permissions': perms},
          );
        }
        if (!mounted) return;
        ToastService.showSuccess(
          existing == null
              ? 'Đã tạo vai trò thành công'
              : 'Đã cập nhật vai trò thành công',
        );
        _load();
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ToastService.showError('Lỗi: $e');
      }
    }
  }

  Future<void> _deleteRole(Map<String, dynamic> role) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Xóa vai trò',
      message: 'Bạn chắc chắn muốn xóa vai trò "${role['name']}"?',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
      isDestructive: true,
    );
    if (confirmed == true) {
      final api = ref.read(apiClientProvider);
      setState(() => _loading = true);
      try {
        await api.delete('/shop-roles/${role['id']}');
        if (!mounted) return;
        ToastService.showSuccess('Đã xóa vai trò thành công');
        _load();
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ToastService.showError('Lỗi: $e');
      }
    }
  }

  dynamic _parseJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Quản lý vai trò',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleEditor(),
        icon: const Icon(Icons.shield_outlined),
        label: Text(
          'Tạo vai trò mới',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _roles.isEmpty
          ? const AppEmpty(
              message: 'Chưa có vai trò nào',
              subtitle: 'Tạo vai trò để phân quyền nhân viên',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _roles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildRoleCard(_roles[i], c, theme),
              ),
            ),
    );
  }

  Widget _buildRoleCard(
    Map<String, dynamic> role,
    AppThemeColors c,
    ThemeData theme,
  ) {
    // Parse permissions for display
    Map<String, String> perms = {};
    final raw = role['permissions'];
    if (raw is String) {
      try {
        Map<String, dynamic>.from(
          Map.castFrom((raw.startsWith('{') ? _parseJson(raw) : {}) as Map),
        ).forEach((k, v) => perms[k] = v.toString());
      } catch (_) {}
    } else if (raw is Map) {
      raw.forEach((k, v) => perms[k.toString()] = v.toString());
    }

    final activePerms = perms.entries.where((e) => e.value != 'none').toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  role['name'] ?? '',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: () => _showRoleEditor(existing: role),
                color: theme.colorScheme.primary,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () => _deleteRole(role),
                color: AppColors.danger,
              ),
            ],
          ),
          if (activePerms.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: activePerms.map((e) {
                final label = _permissionKeys[e.key] ?? e.key;
                final level = _permissionLabels[e.value] ?? e.value;
                final isFull = e.value == 'full';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFull
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFull
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.info.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    '$label: $level',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isFull ? AppColors.success : AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
