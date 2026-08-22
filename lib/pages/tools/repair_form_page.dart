import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:forui/forui.dart';

import '../../services/cas_service.dart';
import '../../services/repair_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'repair_picker_sheet.dart';

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
  final _areaCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
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
    unawaited(_loadTutorial());
    unawaited(_createSession());
  }

  Future<void> _createSession() async {
    try {
      final session = await _service.login(widget.studentId, widget.password);
      if (!mounted) {
        session.close();
        return;
      }
      setState(() {
        _session = session;
        _sessionLoading = false;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('报修会话创建失败', e, stackTrace);
      if (!mounted) return;
      setState(() => _sessionLoading = false);
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      talker.error('报修会话创建异常', e, stackTrace);
      if (!mounted) return;
      setState(() => _sessionLoading = false);
      showAppSnackBar(context, '会话创建失败', severity: ToastSeverity.error);
    }
  }

  Future<void> _loadTutorial() async {
    final content = await rootBundle.loadString(
      'assets/tutorials/repair_guide.md',
    );
    if (mounted) setState(() => _tutorial = content);
  }

  Future<void> _pickImage() async {
    final source = await showAppSheet<ImageSource>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: FSelectTileGroup<ImageSource>(
          control: FMultiValueControl.managedRadio(
            onChange: (values) {
              if (values.isNotEmpty) Navigator.pop(ctx, values.first);
            },
          ),
          children: const [
            FSelectTile<ImageSource>.suffix(
              prefix: Icon(FLucideIcons.camera),
              title: Text('拍照'),
              value: ImageSource.camera,
            ),
            FSelectTile<ImageSource>.suffix(
              prefix: Icon(FLucideIcons.image),
              title: Text('从相册选择'),
              value: ImageSource.gallery,
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
    _areaCtrl.dispose();
    _itemCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickArea() async {
    if (_session == null) return;
    final choice = await _pickAreaByScroll();
    if (choice != null && mounted) {
      setState(() {
        _selectedArea = choice.value;
        _selectedItem = null;
        _areaCtrl.text = choice.label;
        _itemCtrl.clear();
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

  /// 加载并排序一级区域。
  Future<List<RepairArea>> _fetchTopAreas() async {
    List<RepairArea> items;
    try {
      items = await _service.getAreas(_session!);
    } catch (e, stackTrace) {
      talker.error('报修区域获取失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '获取区域失败', severity: ToastSeverity.error);
      }
      return const [];
    }
    items = items.where((a) => !a.name.contains('城南校区')).toList();
    items.sort((a, b) {
      final cmp = _areaSortKey(a.name).compareTo(_areaSortKey(b.name));
      if (cmp != 0) return cmp;
      return _areaSubSortKey(a.name).compareTo(_areaSubSortKey(b.name));
    });
    return items;
  }

  /// 把报修区域整棵树扁平化，生成「一级 > 二级 > …」的完整路径列表。
  Future<List<WheelChoice<RepairArea>>> _loadAreaChoices() async {
    final top = await _fetchTopAreas();
    final result = <WheelChoice<RepairArea>>[];
    for (final area in top) {
      await _collectAreaChoices(area, [area.name], result);
    }
    return result;
  }

  Future<void> _collectAreaChoices(
    RepairArea area,
    List<String> path,
    List<WheelChoice<RepairArea>> out,
  ) async {
    final children = await _loadChildAreasSafe(area.id);
    if (children.isEmpty) {
      out.add(WheelChoice(label: path.join(' > '), value: area));
      return;
    }
    for (final child in children) {
      await _collectAreaChoices(child, [...path, child.name], out);
    }
  }

  Future<List<RepairArea>> _loadChildAreasSafe(String areaId) async {
    try {
      return await _service.getChildAreas(_session!, areaId);
    } catch (e, stackTrace) {
      talker.debug('报修子区域获取失败，按叶子节点处理', e, stackTrace);
      return const [];
    }
  }

  /// 单列滚轮选择：把整棵树合并成一个输入框，一次滚动选中最终地点。
  Future<WheelChoice<RepairArea>?> _pickAreaByScroll() async {
    final choices = await _loadAreaChoices();
    if (choices.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, '没有可选区域', severity: ToastSeverity.warning);
      }
      return null;
    }
    if (!mounted) return null;
    return showAppSheet<WheelChoice<RepairArea>>(
      context: context,
      maxHeightRatio: 0.5,
      builder: (ctx) =>
          SingleWheelSheet<RepairArea>(title: '选择区域', choices: choices),
    );
  }

  Future<void> _pickItem() async {
    if (_session == null) return;
    if (_selectedArea == null) {
      showAppSnackBar(context, '请先选择区域', severity: ToastSeverity.warning);
      return;
    }
    final choice = await _pickItemByScroll();
    if (choice != null && mounted) {
      setState(() {
        _selectedItem = choice.value;
        _itemCtrl.text = choice.label;
      });
    }
  }

  /// 把报修项目整棵树扁平化，生成「一级 > 二级 > …」的完整路径列表。
  Future<List<WheelChoice<RepairItem>>> _loadItemChoices() async {
    final rootItems = await _loadRootItemsSafe();
    final result = <WheelChoice<RepairItem>>[];
    for (final item in rootItems) {
      await _collectItemChoices(item, [item.name], result);
    }
    return result;
  }

  Future<List<RepairItem>> _loadRootItemsSafe() async {
    try {
      return await _service.getItems(_session!, _selectedArea!.id);
    } catch (e, stackTrace) {
      talker.error('报修项目获取失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '获取项目失败', severity: ToastSeverity.error);
      }
      return const [];
    }
  }

  Future<void> _collectItemChoices(
    RepairItem item,
    List<String> path,
    List<WheelChoice<RepairItem>> out,
  ) async {
    final children = await _loadChildItemsSafe(item.id);
    if (children.isEmpty) {
      out.add(WheelChoice(label: path.join(' > '), value: item));
      return;
    }
    for (final child in children) {
      await _collectItemChoices(child, [...path, child.name], out);
    }
  }

  Future<List<RepairItem>> _loadChildItemsSafe(String itemId) async {
    try {
      return await _service.getChildItems(_session!, itemId);
    } catch (e, stackTrace) {
      talker.debug('报修子项目获取失败，按叶子节点处理', e, stackTrace);
      return const [];
    }
  }

  /// 单列滚轮选择：把报修项目整棵树合并成一个输入框，一次滚动选中。
  Future<WheelChoice<RepairItem>?> _pickItemByScroll() async {
    final choices = await _loadItemChoices();
    if (choices.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, '没有可选项目', severity: ToastSeverity.warning);
      }
      return null;
    }
    if (!mounted) return null;
    return showAppSheet<WheelChoice<RepairItem>>(
      context: context,
      maxHeightRatio: 0.5,
      builder: (ctx) =>
          SingleWheelSheet<RepairItem>(title: '选择项目', choices: choices),
    );
  }

  Future<void> _submit() async {
    if (_session == null) return;
    if (_selectedArea == null) {
      showAppSnackBar(context, '请选择区域', severity: ToastSeverity.warning);
      return;
    }
    if (_selectedItem == null) {
      showAppSnackBar(context, '请选择报修项目', severity: ToastSeverity.warning);
      return;
    }
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      showAppSnackBar(context, '请填写故障描述', severity: ToastSeverity.warning);
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
      showAppSnackBar(context, '提交成功', severity: ToastSeverity.success);
      Navigator.of(context).pop(true);
    } on AuthException catch (e, stackTrace) {
      talker.error('报修提交失败', e, stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, e.message, severity: ToastSeverity.error);
    } catch (e, stackTrace) {
      talker.error('报修提交异常', e, stackTrace);
      if (!mounted) return;
      showAppSnackBar(context, '提交失败', severity: ToastSeverity.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _formDisabled => _session == null || _submitting;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppPage(
      title: '新建报修',
      actions: [
        if (_sessionLoading)
          const FHeaderAction(
            icon: FCircularProgress(size: FCircularProgressSizeVariant.sm),
            onPress: null,
          ),
      ],
      child: AppPageListView(
        maxWidth: AppLayout.formMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          _buildPickerField(
            label: '报修区域',
            controller: _areaCtrl,
            onTap: _pickArea,
          ),
          const SizedBox(height: 12),
          _buildPickerField(
            label: '报修项目',
            controller: _itemCtrl,
            onTap: _pickItem,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 140,
            child: AppTextField(
              controller: _addressCtrl,
              label: '详细地址',
              hint: '7B216',
              enabled: !_formDisabled,
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _contentCtrl,
            label: '故障描述',
            enabled: !_formDisabled,
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
          FButton(
            onPress: _formDisabled ? null : _submit,
            prefix: _submitting
                ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
                : const Icon(FLucideIcons.send),
            child: const Text('提交报修'),
          ),
          if (_tutorial != null && _tutorial!.trim().isNotEmpty) ...[
            const SizedBox(height: 28),
            const FDivider(),
            const SizedBox(height: 16),
            MarkdownBody(
              data: _tutorial!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: theme.typography.bodyText.copyWith(
                  color: theme.colors.foreground,
                ),
                h1: theme.typography.pageTitle.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
                h2: theme.typography.tileTitle.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
                h3: theme.typography.sectionTitle.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
                code: theme.typography.body.sm.copyWith(
                  color: theme.colors.foreground,
                  fontFamily: 'monospace',
                  backgroundColor: theme.colors.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickerField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: '请选择',
      readOnly: true,
      enabled: !_formDisabled,
      onTap: onTap,
      suffix: const Icon(FLucideIcons.chevronDown),
    );
  }

  Widget _buildImageTile(FThemeData theme, int index) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
            child: AppIconButton(
              icon: FLucideIcons.x,
              onPress: () => setState(() => _images.removeAt(index)),
              tooltip: '删除图片',
              variant: FButtonVariant.destructive,
              size: FButtonSizeVariant.xs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageTile(FThemeData theme) {
    return FTappable(
      onPress: _formDisabled ? null : _pickImage,
      child: SizedBox(
        width: 90,
        height: 90,
        child: FCard(
          child: Icon(
            FLucideIcons.imagePlus,
            size: 32,
            color: theme.colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
