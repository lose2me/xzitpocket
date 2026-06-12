import 'package:flutter/material.dart';

import '../../services/cas_service.dart';
import '../../services/repair_service.dart';
import '../../utils/snackbar_helper.dart';

class RepairFormPage extends StatefulWidget {
  final CasSession session;
  final RepairUserInfo userInfo;

  const RepairFormPage({
    super.key,
    required this.session,
    required this.userInfo,
  });

  @override
  State<RepairFormPage> createState() => _RepairFormPageState();
}

class _RepairFormPageState extends State<RepairFormPage> {
  final _service = RepairService();
  final _addressCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  RepairArea? _selectedArea;
  RepairItem? _selectedItem;
  bool _submitting = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _contentCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickArea() async {
    final result = await _drillDownAreas();
    if (result != null && mounted) {
      setState(() {
        _selectedArea = result;
        _selectedItem = null;
      });
    }
  }

  Future<RepairArea?> _drillDownAreas() async {
    List<RepairArea> items;
    try {
      items = await _service.getAreas(widget.session);
    } catch (_) {
      if (mounted) showAppSnackBar(context, '获取区域失败');
      return null;
    }
    if (items.isEmpty) {
      if (mounted) showAppSnackBar(context, '没有可选区域');
      return null;
    }

    RepairArea? chosen;
    while (true) {
      if (!mounted) return null;
      chosen = await _showPickerSheet('选择区域', items);
      if (chosen == null) return null;

      List<RepairArea> children;
      try {
        children = await _service.getChildAreas(widget.session, chosen.id);
      } catch (_) {
        return chosen;
      }
      if (children.isEmpty) return chosen;
      items = children;
    }
  }

  Future<void> _pickItem() async {
    if (_selectedArea == null) {
      showAppSnackBar(context, '请先选择区域');
      return;
    }
    final result = await _drillDownItems();
    if (result != null && mounted) {
      setState(() => _selectedItem = result);
    }
  }

  Future<RepairItem?> _drillDownItems() async {
    List<RepairItem> items;
    try {
      items = await _service.getItems(widget.session, _selectedArea!.id);
    } catch (_) {
      if (mounted) showAppSnackBar(context, '获取项目失败');
      return null;
    }
    if (items.isEmpty) {
      if (mounted) showAppSnackBar(context, '没有可选项目');
      return null;
    }

    RepairArea? chosen;
    while (true) {
      if (!mounted) return null;
      chosen = await _showPickerSheet(
        '选择项目',
        items.map((i) => RepairArea(id: i.id, name: i.name)).toList(),
      );
      if (chosen == null) return null;

      List<RepairItem> children;
      try {
        children = await _service.getChildItems(widget.session, chosen.id);
      } catch (_) {
        return RepairItem(id: chosen.id, name: chosen.name);
      }
      if (children.isEmpty) return RepairItem(id: chosen.id, name: chosen.name);
      items = children;
    }
  }

  Future<RepairArea?> _showPickerSheet(
    String title,
    List<RepairArea> items,
  ) {
    return showModalBottomSheet<RepairArea>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (ctx, scrollCtrl) {
            final theme = Theme.of(ctx);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return ListTile(
                        title: Text(item.name),
                        onTap: () => Navigator.of(ctx).pop(item),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_selectedArea == null) {
      showAppSnackBar(context, '请选择区域');
      return;
    }
    if (_selectedItem == null) {
      showAppSnackBar(context, '请选择报修项目');
      return;
    }
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      showAppSnackBar(context, '请填写故障描述');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submitRepair(
        widget.session,
        areaId: _selectedArea!.id,
        itemId: _selectedItem!.id,
        address: _addressCtrl.text.trim(),
        content: content,
        phone: widget.userInfo.phone,
        repairer: widget.userInfo.username,
        remark: _remarkCtrl.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(context, '提交成功');
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '提交失败');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('新建报修'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildPickerField(
              theme,
              label: '报修区域',
              value: _selectedArea?.name,
              onTap: _pickArea,
            ),
            const SizedBox(height: 12),
            _buildPickerField(
              theme,
              label: '报修项目',
              value: _selectedItem?.name,
              onTap: _pickItem,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: '详细地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: '故障描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarkCtrl,
              decoration: const InputDecoration(
                labelText: '补充说明（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('提交报修'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerField(
    ThemeData theme, {
    required String label,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _submitting ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? '请选择',
          style: value == null
              ? theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
