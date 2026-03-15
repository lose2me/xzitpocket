import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../utils/snackbar_helper.dart';
import 'color_picker_sheet.dart';

class CourseFormPage extends StatefulWidget {
  final int weekday;
  final int session;
  final Course? existingCourse;
  final Color? defaultColor;
  final ValueChanged<Course> onSave;
  final VoidCallback? onDelete;

  const CourseFormPage({
    super.key,
    required this.weekday,
    required this.session,
    this.existingCourse,
    this.defaultColor,
    required this.onSave,
    this.onDelete,
  });

  bool get isEditing => existingCourse != null;

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _campusCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController(text: '1-16');
  final _colorCtrl = TextEditingController();
  final _weekdayCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  Color _currentColor = Course.colors[0];

  @override
  void initState() {
    super.initState();
    final c = widget.existingCourse;
    if (c != null) {
      _titleCtrl.text = c.title;
      _teacherCtrl.text = c.teacher;
      _placeCtrl.text = c.place;
      _campusCtrl.text = c.campus;
      _weeksCtrl.text = _formatWeeksForEdit(c.weeks);
      _weekdayCtrl.text = c.weekday.toString();
      _startCtrl.text = c.startSession.toString();
      _endCtrl.text = c.endSession.toString();
      _currentColor = c.color;
    } else {
      _weekdayCtrl.text = widget.weekday.toString();
      _startCtrl.text = widget.session.toString();
      _endCtrl.text = (widget.session + 1).clamp(1, 14).toString();
      if (widget.defaultColor != null) {
        _currentColor = widget.defaultColor!;
      }
    }
    _colorCtrl.text = _colorToHex(_currentColor);
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).substring(2).toUpperCase();
  }

  String _formatWeeksForEdit(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = [...weeks]..sort();
    final ranges = <String>[];
    int start = sorted[0];
    int end = sorted[0];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add(start == end ? '$start' : '$start-$end');
        start = sorted[i];
        end = sorted[i];
      }
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    return ranges.join(',');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _teacherCtrl.dispose();
    _placeCtrl.dispose();
    _campusCtrl.dispose();
    _weeksCtrl.dispose();
    _colorCtrl.dispose();
    _weekdayCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑课程' : '添加课程'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.existingCourse?.courseId.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '编号: ${widget.existingCourse!.courseId}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '课程名称',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _teacherCtrl,
              decoration: const InputDecoration(
                labelText: '教师',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placeCtrl,
              decoration: const InputDecoration(
                labelText: '地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _campusCtrl,
              decoration: const InputDecoration(
                labelText: '校区',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weeksCtrl,
              decoration: const InputDecoration(
                labelText: '周次 (例: 1-16)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weekdayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '星期 (1-7)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 7) return '请输入1-7';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '开始节次 (1-14)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 14) return '请输入1-14';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '结束节次 (1-14)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 14) return '请输入1-14';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _colorCtrl,
                    decoration: const InputDecoration(
                      labelText: '颜色 (HEX)',
                      hintText: 'FF8800',
                      prefixText: '#',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入颜色值';
                      final hex = v.replaceAll('#', '').trim();
                      if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                        return '请输入6位HEX颜色值';
                      }
                      return null;
                    },
                    onChanged: (v) {
                      final hex = v.replaceAll('#', '').trim();
                      if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                        setState(() {
                          _currentColor = Color(int.parse('FF$hex', radix: 16));
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _openColorPicker,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.onDelete != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: _confirmDelete,
                    child: const Text('删除'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _openColorPicker() async {
    final picked = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ColorPickerSheet(initialColor: _currentColor),
    );
    if (picked != null) {
      setState(() {
        _currentColor = picked;
        _colorCtrl.text = _colorToHex(picked);
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final weekday = int.parse(_weekdayCtrl.text);
    final startSession = int.parse(_startCtrl.text);
    final endSession = int.parse(_endCtrl.text);

    if (startSession > endSession) {
      showAppSnackBar(context, '开始节次不能大于结束节次');
      return;
    }

    final sessions = List.generate(
      endSession - startSession + 1,
      (i) => startSession + i,
    );
    final weeks = _parseWeeks(_weeksCtrl.text);
    final existing = widget.existingCourse;

    widget.onSave(
      Course(
        title: _titleCtrl.text,
        teacher: _teacherCtrl.text,
        weekday: weekday,
        sessions: sessions,
        weeks: weeks,
        campus: _campusCtrl.text,
        place: _placeCtrl.text,
        colorIndex: _currentColor.toARGB32(),
        courseId: existing?.courseId ?? '',
      ),
    );
    Navigator.pop(context);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: const Text('确定要删除这门课程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete!();
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<int> _parseWeeks(String text) {
    if (text.isEmpty) return List.generate(16, (i) => i + 1);
    final result = <int>[];
    for (final match in RegExp(r'(\d+)\s*-\s*(\d+)|(\d+)').allMatches(text)) {
      if (match.group(1) != null && match.group(2) != null) {
        final start = int.parse(match.group(1)!);
        final end = int.parse(match.group(2)!);
        for (int i = start; i <= end; i++) {
          result.add(i);
        }
      } else {
        result.add(int.parse(match.group(3)!));
      }
    }
    return result;
  }
}
