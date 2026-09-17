import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inspection_item.dart';
import '../../data/models/inspection_report.dart';
import '../../data/services/mock_inspection_service.dart';
import '../widgets/inspection_card.dart';
import '../widgets/sticky_forensic_footer.dart';
import 'report_screen.dart';

/// Screen: Inspection Logs & Case Audit Register
/// Allows officers to view, search, and filter all historical package inspections,
/// inspect detailed violation memos, and export official audit logs.
class LogsScreen extends StatefulWidget {
  final VoidCallback? onNewInspectionPressed;

  const LogsScreen({
    super.key,
    this.onNewInspectionPressed,
  });

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final MockInspectionService _service = MockInspectionService();
  final TextEditingController _searchController = TextEditingController();

  List<InspectionItem> _allItems = [];
  List<InspectionItem> _filteredItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL'; // 'ALL', 'VIOLATIONS', 'COMPLIANT'
  String _selectedCategory = 'ALL'; // 'ALL', 'FONT', 'WEIGHT', 'MRP', 'COMPLIANT'

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final list = await _service.getRecentInspections();
    if (mounted) {
      setState(() {
        _allItems = list;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchesQuery = query.isEmpty ||
            item.productName.toLowerCase().contains(query) ||
            item.businessName.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            (item.violationReason ?? '').toLowerCase().contains(query);

        if (!matchesQuery) return false;

        // Status filter
        if (_selectedFilter == 'VIOLATIONS' && !item.isViolation) return false;
        if (_selectedFilter == 'COMPLIANT' && !item.isPass) return false;

        // Category filter (User Requirement: Category-wise Logs)
        if (_selectedCategory != 'ALL') {
          final cat = item.category.toLowerCase();
          if (_selectedCategory == 'FONT' && !cat.contains('font')) return false;
          if (_selectedCategory == 'WEIGHT' && !cat.contains('weight')) return false;
          if (_selectedCategory == 'MRP' && !cat.contains('mrp')) return false;
          if (_selectedCategory == 'COMPLIANT' && !cat.contains('compliant')) return false;
        }

        return true;
      }).toList();
    });
  }

  void _openReport(InspectionItem item) {
    final report = item.fullReport ??
        (item.isViolation
            ? InspectionReport.mockOilViolation()
            : InspectionReport.mockAttaCompliant());

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportScreen(report: report, isSavedRecord: true),
      ),
    );
  }

  void _exportAuditLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryNavy),
            SizedBox(width: 8),
            Text('Export Audit Register'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Official Form V Inspection Register ready for digital export:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Records: ${_allItems.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Violations Flagged: ${_allItems.where((i) => i.isViolation).length}', style: const TextStyle(fontSize: 12, color: AppTheme.violationText)),
                  Text('Compliant Inspections: ${_allItems.where((i) => i.isPass).length}', style: const TextStyle(fontSize: 12, color: AppTheme.passText)),
                  const SizedBox(height: 4),
                  const Text('Format: Standard Govt CSV & Digitally Signed PDF', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download Register'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Audit Register exported and synced with State Enforcement Server.'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _allItems.length;
    final violations = _allItems.where((i) => i.isViolation).length;
    final compliant = _allItems.where((i) => i.isPass).length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inspection Case Logs',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Enforcement Register • PCR 2011 Audit Records',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Export Audit Log',
            onPressed: _exportAuditLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Logs',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        color: AppTheme.primaryNavy,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Top Metrics Register Summary
                _buildSummaryBanner(totalCount, compliant, violations),
                const SizedBox(height: 16),

                // Search Bar
                _buildSearchBar(),
                const SizedBox(height: 14),

                // Filter Chips
                _buildFilterChips(),
                const SizedBox(height: 16),

                // List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Case Records (${_filteredItems.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (_selectedFilter != 'ALL' || _searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _selectedFilter = 'ALL';
                            _selectedCategory = 'ALL';
                          });
                          _applyFilters();
                        },
                        child: const Text(
                          'Reset Filters',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // List of Inspection Cards
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filteredItems.isEmpty)
                  _buildEmptySearchState()
                else
                  ..._filteredItems.map(
                    (item) => InspectionCard(
                      item: item,
                      onTap: () => _openReport(item),
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const StickyForensicFooter(),
    );
  }

  Widget _buildSummaryBanner(int total, int compliant, int violations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutralBorder, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetric('Total Audited', '$total', AppTheme.primaryNavy),
          Container(width: 1, height: 28, color: AppTheme.borderLight),
          _buildMetric('Compliant', '$compliant', AppTheme.passGreen),
          Container(width: 1, height: 28, color: AppTheme.borderLight),
          _buildMetric('Violations', '$violations', AppTheme.violationRed),
        ],
      ),
    );
  }

  Widget _buildMetric(String title, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _applyFilters(),
      decoration: InputDecoration(
        hintText: 'Search by Product, Shop, or Case ID...',
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 20),
                onPressed: () {
                  _searchController.clear();
                  _applyFilters();
                },
              )
            : null,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Row (All, Violations, Compliant)
        Row(
          children: [
            _buildChip('ALL', 'All Cases (${_allItems.length})'),
            const SizedBox(width: 8),
            _buildChip('VIOLATIONS', 'Violations (${_allItems.where((i) => i.isViolation).length})', isViolation: true),
            const SizedBox(width: 8),
            _buildChip('COMPLIANT', 'Compliant (${_allItems.where((i) => i.isPass).length})', isCompliant: true),
          ],
        ),
        const SizedBox(height: 10),

        // Statutory Category Scrollable Strip (User Requirement: Category-wise Logs)
        Row(
          children: [
            const Icon(Icons.filter_list_rounded, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            const Text('Categories: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryPill('ALL', 'All Categories'),
                    const SizedBox(width: 6),
                    _buildCategoryPill('FONT', 'Font Violations'),
                    const SizedBox(width: 6),
                    _buildCategoryPill('WEIGHT', 'Weight Shortage'),
                    const SizedBox(width: 6),
                    _buildCategoryPill('MRP', 'MRP Tampering'),
                    const SizedBox(width: 6),
                    _buildCategoryPill('COMPLIANT', 'Compliant Packages'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String catKey, String label) {
    final isSelected = _selectedCategory == catKey;
    return InkWell(
      key: ValueKey('cat_filter_$catKey'),
      onTap: () {
        setState(() => _selectedCategory = catKey);
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : AppTheme.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String filterKey, String label, {bool isViolation = false, bool isCompliant = false}) {
    final isSelected = _selectedFilter == filterKey;

    Color bg;
    Color border;
    Color text;

    if (isSelected) {
      if (isViolation) {
        bg = AppTheme.violationRed;
        border = AppTheme.violationRed;
        text = Colors.white;
      } else if (isCompliant) {
        bg = AppTheme.passGreen;
        border = AppTheme.passGreen;
        text = Colors.white;
      } else {
        bg = AppTheme.primaryNavy;
        border = AppTheme.primaryNavy;
        text = Colors.white;
      }
    } else {
      bg = Colors.white;
      border = AppTheme.borderLight;
      text = AppTheme.textPrimary;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedFilter = filterKey);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      padding: const EdgeInsets.all(36),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'No matching inspection cases found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try altering your search keywords or switching filter tabs.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _selectedFilter = 'ALL');
              _applyFilters();
            },
            child: const Text('Reset All Filters'),
          ),
        ],
      ),
    );
  }
}
