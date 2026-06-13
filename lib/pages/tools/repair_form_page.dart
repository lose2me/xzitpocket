import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cas_service.dart';
import '../../services/repair_service.dart';
import '../../utils/snackbar_helper.dart';

class RepairFormPage extends StatefulWidget {
  final String studentId;
  final String password;
  final RepairUserInfo userInfo;

  const RepairFormPage({
    super.key,
    required this.studentId,
    required this.password,
    required this.userInfo,
  });

  @override
  State<RepairFormPage> createState() => _RepairFormPageState();
}

class _RepairFormPageState extends State<RepairFormPage> {
  final _service = RepairService();
  final _picker = ImagePicker();
  final _addressCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _images = <XFile>[];
  String? _tutorial;

  CasSession? _session;
  bool _sessionLoading = true;

  RepairArea? _selectedArea;
  RepairItem? _selectedItem;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTutorial();
    _createSession();
  }

  Future<void> _createSession() async {
    try {
      final session = await _service.login(
        widget.studentId,
        widget.password,
      );
      if (!mounted) {
        session.close();
        return;
      }
      setState(() {
        _session = session;
        _sessionLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _sessionLoading = false);
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sessionLoading = false);
      showAppSnackBar(context, '会话创建失败');
    }
  }

  Future<void> _loadTutorial() async {
    final content =
        await rootBundle.loadString('assets/tutorials/repair_guide.md');
    if (mounted) setState(() => _tutorial = content);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked != null && mounted) {
      setState(() => _images.add(picked));
    }
  }

  @override
  void dispose() {
    _session?.close();
    _addressCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickArea() async {
    if (_session == null) return;
    final result = await _drillDownAreas();
    if (result != null && mounted) {
      setState(() {
        _selectedArea = result;
        _selectedItem = null;
      });
    }
  }

  static int _areaSortKey(String name) {
    if (name.contains('中心校区')) return 0;
    if (name.contains('东校区')) return 1;
    return 2;
  }

  static int _areaSubSortKey(String name) {
    if (name.contains('公寓')) return 0;
    if (name.contains('楼宇')) return 1;
    if (name.contains('食堂')) return 2;
    return 3;
  }

  Future<RepairArea?> _drillDownAreas() async {
    List<RepairArea> items;
    try {
      items = await _service.getAreas(_session!);
    } catch (_) {
      if (mounted) showAppSnackBar(context, '获取区域失败');
      return null;
    }

    items = items.where((a) => !a.name.contains('城南校区')).toList();
    items.sort((a, b) {
      final cmp = _areaSortKey(a.name).compareTo(_areaSortKey(b.name));
      if (cmp != 0) return cmp;
      return _areaSubSortKey(a.name).compareTo(_areaSubSortKey(b.name));
    });
    if (items.isEmpty) {
      if (mounted) showAppSnackBar(context, '没有可选区域');
      return null;
    }

    RepairArea? chosen;
    while (true) {
      if (!mounted) return null;
      chosen = await _showPickerSheet('选择区域', items,
          selectedId: _selectedArea?.id);
      if (chosen == null) return null;

      List<RepairArea> children;
      try {
        children = await _service.getChildAreas(_session!, chosen.id);
      } catch (_) {
        return chosen;
      }
      if (children.isEmpty) return chosen;
      items = children;
    }
  }

  Future<void> _pickItem() async {
    if (_session == null) return;
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
      items = await _service.getItems(_session!, _selectedArea!.id);
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
        selectedId: _selectedItem?.id,
      );
      if (chosen == null) return null;

      List<RepairItem> children;
      try {
        children = await _service.getChildItems(_session!, chosen.id);
      } catch (_) {
        return RepairItem(id: chosen.id, name: chosen.name);
      }
      if (children.isEmpty) {
        return RepairItem(id: chosen.id, name: chosen.name);
      }
      items = children;
    }
  }

  Future<RepairArea?> _showPickerSheet(
    String title,
    List<RepairArea> items, {
    String? selectedId,
  }) {
    return showModalBottomSheet<RepairArea>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final maxH = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            constraints: BoxConstraints(maxHeight: maxH),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      final selected = item.id == selectedId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: selected
                              ? theme.colorScheme.primaryContainer
                                  .withAlpha(72)
                              : theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () => Navigator.pop(ctx, item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_session == null) return;
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
      final imagePaths = await _service.uploadImages(
        _session!,
        _images.map((x) => File(x.path)).toList(),
      );
      await _service.submitRepair(
        _session!,
        areaId: _selectedArea!.id,
        itemId: _selectedItem!.id,
        address: _addressCtrl.text.trim(),
        content: content,
        phone: widget.userInfo.phone,
        repairer: widget.userInfo.username,
        remark: '',
        images: imagePaths,
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

  bool get _formDisabled => _session == null || _submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新建报修'),
        centerTitle: true,
        actions: [
          if (_sessionLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
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
            SizedBox(
              width: 140,
              child: TextField(
                controller: _addressCtrl,
                enabled: !_formDisabled,
                decoration: const InputDecoration(
                  labelText: '宿舍号',
                  hintText: '7B216',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              enabled: !_formDisabled,
              decoration: const InputDecoration(
                labelText: '故障描述',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  _buildImageTile(theme, i),
                if (_images.length < 9) _buildAddImageTile(theme),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _formDisabled ? null : _submit,
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
            if (_tutorial != null && _tutorial!.trim().isNotEmpty) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              MarkdownBody(
                data: _tutorial!,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium,
                  h1: theme.textTheme.titleLarge,
                  h2: theme.textTheme.titleMedium,
                ),
              ),
            ],
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
      onTap: _formDisabled ? null : onTap,
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

  Widget _buildImageTile(ThemeData theme, int index) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(_images[index].path),
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => setState(() => _images.removeAt(index)),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageTile(ThemeData theme) {
    return GestureDetector(
      onTap: _formDisabled ? null : _pickImage,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(60),
          ),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
