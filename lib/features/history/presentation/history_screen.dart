import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/services/storage_service.dart';
import '../../home/widgets/recent_recordings_list.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all';
  static const int _pageSize = 10;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();
  
  // Selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Pagination is handled in the build method
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Recordings?'),
        content: Text('Delete $count recording${count > 1 ? 's' : ''}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storageService = ref.read(storageServiceProvider);
      for (final id in _selectedIds) {
        await storageService.deleteRecording(id);
      }
      ref.invalidate(recordingsProvider);
      _exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count recording${count > 1 ? 's' : ''} deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingsAsync = ref.watch(recordingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: _exitSelectionMode,
              )
            : null,
        title: _isSelectionMode 
            ? Text('${_selectedIds.length} selected')
            : const Text('History'),
        automaticallyImplyLeading: false,
        actions: _isSelectionMode ? [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: AppTheme.errorColor),
            onPressed: _deleteSelected,
            tooltip: 'Delete Selected',
          ),
        ] : null,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search recordings...',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'all',
                  onTap: () => setState(() => _selectedFilter = 'all'),
                ),
                _FilterChip(
                  label: 'Today',
                  isSelected: _selectedFilter == 'today',
                  onTap: () => setState(() => _selectedFilter = 'today'),
                ),
                _FilterChip(
                  label: 'This Week',
                  isSelected: _selectedFilter == 'week',
                  onTap: () => setState(() => _selectedFilter = 'week'),
                ),
                _FilterChip(
                  label: 'This Month',
                  isSelected: _selectedFilter == 'month',
                  onTap: () => setState(() => _selectedFilter = 'month'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recordings list
          Expanded(
            child: recordingsAsync.when(
              data: (recordings) {
                // Apply filters
                var filtered = recordings;

                // Search filter
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filtered = filtered.where((r) {
                    return r.title.toLowerCase().contains(query) ||
                        (r.transcript?.toLowerCase().contains(query) ??
                            false) ||
                        (r.summary?.toLowerCase().contains(query) ?? false);
                  }).toList();
                }

                // Date filter
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                if (_selectedFilter == 'today') {
                  filtered =
                      filtered.where((r) => r.date.isAfter(today)).toList();
                } else if (_selectedFilter == 'week') {
                  final weekAgo = today.subtract(const Duration(days: 7));
                  filtered =
                      filtered.where((r) => r.date.isAfter(weekAgo)).toList();
                } else if (_selectedFilter == 'month') {
                  final monthAgo = DateTime(now.year, now.month - 1, now.day);
                  filtered =
                      filtered.where((r) => r.date.isAfter(monthAgo)).toList();
                }

                if (filtered.isEmpty) {
                  return _EmptyState(
                    hasFilters:
                        _searchQuery.isNotEmpty || _selectedFilter != 'all',
                  );
                }

                // Paginate results
                final totalPages = (filtered.length / _pageSize).ceil();
                final displayCount =
                    ((_currentPage + 1) * _pageSize).clamp(0, filtered.length);
                final paginatedRecordings =
                    filtered.take(displayCount).toList();
                final hasMore = displayCount < filtered.length;

                return Column(
                  children: [
                    // Results count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} recording${filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (totalPages > 1)
                            Text(
                              'Showing ${paginatedRecordings.length} of ${filtered.length}',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Recordings list
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            paginatedRecordings.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= paginatedRecordings.length) {
                            // Load more button
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() => _currentPage++);
                                  },
                                  icon: const Icon(LucideIcons.chevronDown,
                                      size: 18),
                                  label: Text(
                                      'Load more (${filtered.length - displayCount} remaining)'),
                                ),
                              ),
                            );
                          }
                          final rec = paginatedRecordings[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RecordingCard(
                              recording: rec,
                              isSelectable: _isSelectionMode,
                              isSelected: _selectedIds.contains(rec.id),
                              onSelectToggle: () => _toggleSelection(rec.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error loading recordings',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;

  const _EmptyState({this.hasFilters = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? LucideIcons.searchX : LucideIcons.folderOpen,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No matching recordings' : 'No recordings yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Start recording to see your history here',
              style: const TextStyle(color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
