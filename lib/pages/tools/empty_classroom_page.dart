import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/semester_config.dart';
import '../../constants/time_slots.dart';
import '../../services/auth_service.dart';
import '../../services/cas_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/week_calculator.dart';

const _sessionGroups = [
  (label: '1-2', sessions: [1, 2]),
  (label: '3-4', sessions: [3, 4]),
  (label: '5-6', sessions: [5, 6]),
  (label: '7-8', sessions: [7, 8]),
  (label: '9-10', sessions: [9, 10]),
  (label: '11-12', sessions: [11, 12]),
  (label: '13-14', sessions: [13, 14]),
];

const _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class EmptyClassroomPage extends StatefulWidget {
  final String studentId;
  final String password;

  const EmptyClassroomPage({
    super.key,
    required this.studentId,
    required this.password,
  });

  @override
  State<EmptyClassroomPage> createState() => _EmptyClassroomPageState();
}

class _EmptyClassroomPageState extends State<EmptyClassroomPage> {
  ClassroomResult? _result;
  bool _loading = false;
  String? _selectedCampus;
  String? _selectedBuilding;
  String? _selectedType;
  String _searchName = '';
  int _minSeats = 0;
  int _page = 0;
  static const _pageSize = 7;

  late int _week;
  late int _weekday;
  int _selectedGroup = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _week = currentWeek(semesterStartDate).clamp(1, 20);
    _weekday = now.weekday;
    _selectedGroup = _currentSessionGroup(now);
    unawaited(_load());
  }

  int _currentSessionGroup(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    for (var i = 0; i < _sessionGroups.length; i++) {
      final lastSlot = _sessionGroups[i].sessions.last;
      final slot = kTimeSlots[lastSlot - 1];
      final endParts = slot.end.split(':');
      final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      if (minutes <= endMin) return i;
    }
    return 0;
  }

  List<int> get _sessions => _sessionGroups[_selectedGroup].sessions;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService().fetchClassrooms(
        widget.studentId,
        widget.password,
        week: _week,
        weekday: _weekday,
        sessions: _sessions,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _page = 0;
        if (result.campuses.isNotEmpty && _selectedCampus == null) {
          _selectedCampus = result.campuses.first;
        }
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('空教室查询失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('空教室查询异常', e, stackTrace);
      if (mounted) showAppSnackBar(context, '加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Classroom> get _filtered {
    if (_result == null) return [];
    return _result!.classrooms.where((c) {
      if (_selectedCampus != null && c.campus != _selectedCampus) return false;
      if (_selectedBuilding != null && c.building != _selectedBuilding) {
        return false;
      }
      if (_selectedType != null && c.type != _selectedType) return false;
      if (_minSeats > 0 && c.seats < _minSeats) return false;
      if (_searchName.isNotEmpty && !c.name.contains(_searchName)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> get _availableTypes {
    if (_result == null) return [];
    return _result!.classrooms.map((c) => c.type).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rooms = _filtered;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('空教室查询'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            _buildTimeFilters(theme),
            const Divider(height: 1),
            _buildLocationFilters(theme),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(theme, rooms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _weekDropdown(theme),
              const SizedBox(width: 8),
              Expanded(child: _weekdayChips(theme)),
            ],
          ),
          const SizedBox(height: 8),
          _sessionChips(theme),
        ],
      ),
    );
  }

  Widget _weekDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _week,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          items: List.generate(
            20,
            (i) => DropdownMenuItem(
              value: i + 1,
              child: Text('第${i + 1}周', style: const TextStyle(fontSize: 13)),
            ),
          ),
          onChanged: (v) {
            if (v == null || v == _week) return;
            setState(() => _week = v);
            unawaited(_load());
          },
        ),
      ),
    );
  }

  Widget _weekdayChips(ThemeData theme) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final selected = _weekday == i + 1;
          return ChoiceChip(
            label: Text(
              _weekdayLabels[i],
              style: TextStyle(
                fontSize: 12,
                color: selected ? theme.colorScheme.onPrimary : null,
              ),
            ),
            selected: selected,
            selectedColor: theme.colorScheme.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _weekday = i + 1);
              unawaited(_load());
            },
          );
        },
      ),
    );
  }

  Widget _sessionChips(ThemeData theme) {
    return Wrap(
      spacing: 6,
      children: List.generate(_sessionGroups.length, (i) {
        final selected = _selectedGroup == i;
        return ChoiceChip(
          label: Text(
            _sessionGroups[i].label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? theme.colorScheme.onPrimary : null,
            ),
          ),
          selected: selected,
          selectedColor: theme.colorScheme.primary,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          showCheckmark: false,
          onSelected: (_) {
            setState(() => _selectedGroup = i);
            unawaited(_load());
          },
        );
      }),
    );
  }

  Widget _buildLocationFilters(ThemeData theme) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final buildings = _selectedCampus != null
        ? (result.buildingsByCampus[_selectedCampus] ?? [])
        : <String>[];
    final types = _availableTypes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  value: _selectedCampus,
                  hint: '校区',
                  items: result.campuses,
                  onChanged: (v) => setState(() {
                    _selectedCampus = v;
                    _selectedBuilding = null;
                    _page = 0;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown(
                  value: buildings.contains(_selectedBuilding)
                      ? _selectedBuilding
                      : null,
                  hint: '全部教学楼',
                  items: buildings,
                  onChanged: (v) => setState(() {
                    _selectedBuilding = v;
                    _page = 0;
                  }),
                  showAll: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  value: _selectedType,
                  hint: '全部类型',
                  items: types,
                  onChanged: (v) => setState(() {
                    _selectedType = v;
                    _page = 0;
                  }),
                  showAll: true,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '最少座位',
                      hintStyle: TextStyle(fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                    onChanged: (v) => setState(() {
                      _minSeats = int.tryParse(v) ?? 0;
                      _page = 0;
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索教室名称',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 0,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) => setState(() {
                _searchName = v.trim();
                _page = 0;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool showAll = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          items: [
            if (showAll)
              DropdownMenuItem<String>(value: null, child: Text(hint)),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme, List<Classroom> rooms) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无空教室',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final totalPages = (rooms.length / _pageSize).ceil();
    final page = _page.clamp(0, totalPages - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, rooms.length);
    final pageRooms = rooms.sublist(start, end);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200 && page < totalPages - 1) {
          setState(() => _page = page + 1);
        } else if (details.primaryVelocity! > 200 && page > 0) {
          setState(() => _page = page - 1);
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '共 ${rooms.length} 间空教室',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final room in pageRooms) _buildRoomTile(theme, room),
                ],
              ),
            ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${page + 1} / $totalPages',
                    style: theme.textTheme.bodyMedium,
                  ),
                  IconButton(
                    onPressed: page < totalPages - 1
                        ? () => setState(() => _page = page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(ThemeData theme, Classroom room) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                room.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                room.type,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_seat_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  '${room.seats}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
