import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../data/services/receipt_template_service.dart';
import '../../../data/services/external_printer_service.dart';
import '../../../data/services/receipt_style_parser.dart';
import '../../../data/models/receipt_template_model.dart';
import '../../../data/models/receipt_editor_config.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/dialog.dart';
import '../../../app/theme/app_theme.dart';

class ReceiptSettingsView extends StatefulWidget {
  final ReceiptEditorConfig config;

  const ReceiptSettingsView({
    super.key,
    this.config = ReceiptEditorConfig.custody,
  });

  @override
  State<ReceiptSettingsView> createState() => _ReceiptSettingsViewState();
}

class _ReceiptSettingsViewState extends State<ReceiptSettingsView> {
  late ReceiptTemplateService _templateService;
  late ExternalPrinterService _printerService;

  // ==================== 样式常量定义 ====================
  // 主题颜色
  static const Color _warningColor = Color(0xFFFF9800); // 警告橙色（未保存提示）
  static const Color _infoColor = Color(0xFFF57C00); // 信息橙色（指南标题）
  static const Color _codeColor = Color(0xFFE65100); // 代码橙色（占位符）

  // 背景颜色
  static const Color _backgroundColor = AppTheme.backgroundGrey; // 主背景灰
  static const Color _lightBg1 = Color(0xFFF0F0F0); // 浅灰背景1
  static const Color _lightBg2 = AppTheme.backgroundGrey; // 浅灰背景2
  static const Color _highlightBg = AppTheme.warningBgColor; // 高亮背景

  // 边框颜色
  static const Color _borderColor = AppTheme.borderColor; // 标准边框
  static const Color _highlightBorder = Color(0xFFFFE082); // 高亮边框

  // 文字颜色
  static const Color _textPrimary = Color(0xFF2C3E50); // 主文字（深蓝灰）
  static const Color _textDark = AppTheme.textPrimary; // 深色文字
  static const Color _textSecondary = AppTheme.textSecondary; // 次要文字
  static const Color _textTertiary = Color(0xFF7F8C8D); // 三级文字
  static const Color _textDisabled = Color(0xFFBDBDBD); // 禁用文字
  static const Color _textLight = AppTheme.textTertiary; // 浅色文字

  // 间距常量
  static const double _spacingS = 8.0; // 小间距
  static const double _spacingM = 12.0; // 中间距
  static const double _spacingL = 16.0; // 大间距

  // ======================================================

  final _contentController = TextEditingController();
  final _selectedType = Rx<ReceiptTemplateType>(ReceiptTemplateType.custody);
  final _isSaving = false.obs;
  final _isPrinting = false.obs;
  final _hasUnsavedChanges = false.obs;
  final _templateContent = ''.obs; // 响应式模板内容，用于实时预览
  final _leftPanelFlex = 48.obs; // 左侧标签指南区域的flex比例 (默认48，右侧编辑器52)
  final _editorRowKey = GlobalKey(); // 用于获取编辑器Row的实际宽度

  @override
  void initState() {
    super.initState();
    // 根据配置设置初始类型
    _selectedType.value = widget.config.type;
    // 使用 Future.microtask 来调用异步初始化
    Future.microtask(() => _initServices());
  }

  Future<void> _initServices() async {
    try {
      _templateService = Get.find<ReceiptTemplateService>();
    } catch (e) {
      _templateService = Get.put(ReceiptTemplateService());
      _templateService.init();
    }

    try {
      _printerService = Get.find<ExternalPrinterService>();
    } catch (e) {
      // 服务未初始化，主动创建并初始化
      _printerService = Get.put(ExternalPrinterService());
      await _printerService.init(); // 等待打印机服务初始化完成（包括USB扫描）
    }

    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    final template = await _templateService.getTemplate(_selectedType.value);
    if (template != null) {
      _contentController.text = template.content;
      _templateContent.value = template.content; // 同步更新响应式内容
      _hasUnsavedChanges.value = false;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Row(
        children: [
          // 左侧大列：标题+Tab按钮 + 编辑区（74%）
          Expanded(
            flex: 74,
            child: Column(
              children: [
                // 顶部：标题+描述（左） + Tab按钮（右）
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingXL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: _borderColor, width: 1.w),
                    ),
                  ),
                  child: _buildHeader(),
                ),
                // 内容区：占位符指南 + 模板编辑器
                Expanded(child: _buildEditorContent()),
              ],
            ),
          ),
          // 右侧列：预览区域（26%，全高度）
          Expanded(
            flex: 26,
            child: Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
                border: Border(
                  left: BorderSide(color: _borderColor, width: 1.w),
                ),
              ),
              child: _buildPreviewSection(),
            ),
          ),
        ],
      ),
    );
  }

  /// 编辑器区域（占位符指南 + 模板编辑器）
  Widget _buildEditorContent() {
    return Obx(
      () => Row(
        key: _editorRowKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：标签使用指南（独立滚动）
          Expanded(
            flex: _leftPanelFlex.value,
            child: Container(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppTheme.spacingL),
                child: _buildPlaceholderGuide(),
              ),
            ),
          ),
          // 可拖拽的分隔条
          _buildDraggableDivider(),
          // 右侧：模板编辑器（独立滚动）
          Expanded(
            flex: 100 - _leftPanelFlex.value,
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTemplateEditor()),
                  SizedBox(height: 24.h),
                  Center(child: _buildActionButtons()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个Tab按钮
  Widget _buildTabButton(ReceiptTemplateType type, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        if (_hasUnsavedChanges.value) {
          final shouldSwitch = await _showUnsavedChangesDialog();
          if (shouldSwitch != true) return;
        }
        _selectedType.value = type;
        await _loadTemplate();
      },
      child: Container(
        margin: EdgeInsets.only(right: 8.w, top: 8.h, bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getTypeIcon(type),
              size: 18.sp,
              color: isSelected ? Colors.white : _textSecondary,
            ),
            SizedBox(width: 8.w),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取小票类型图标
  IconData _getTypeIcon(ReceiptTemplateType type) {
    switch (type) {
      case ReceiptTemplateType.custody:
        return Icons.inventory_2_outlined;
      case ReceiptTemplateType.payment:
        return Icons.payment_outlined;
      case ReceiptTemplateType.exchange:
        return Icons.swap_horiz_outlined;
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // 左侧：标题 + 描述
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.config.title,
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              widget.config.description,
              style: TextStyle(fontSize: 16.sp, color: _textTertiary),
            ),
          ],
        ),
        const Spacer(),
        // 右侧：Tab按钮
        _buildReceiptTypeTabs(),
      ],
    );
  }

  /// 小票类型Tab按钮组（水平排列）
  Widget _buildReceiptTypeTabs() {
    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        children: ReceiptTemplateType.values.map((type) {
          final isSelected = _selectedType.value == type;
          return _buildTabButton(type, isSelected);
        }).toList(),
      ),
    );
  }


  Widget _buildPlaceholderGuide() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF8E1),
            const Color(0xFFFFECB3).withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFFFD54F).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 20.sp,
                  color: _infoColor,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                '可用占位符说明',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: _infoColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 8.h,
            children: widget.config.placeholders
                .map(
                  (info) => _buildPlaceholderChip(
                    info.placeholder,
                    info.description,
                  ),
                )
                .toList(),
          ),
          SizedBox(height: _spacingL.h),
          Divider(color: _highlightBorder),
          SizedBox(height: _spacingM.h),
          Row(
            children: [
              Icon(Icons.format_paint, size: 20.sp, color: _infoColor),
              SizedBox(width: _spacingS.w),
              Text(
                '样式标记',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: _infoColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStyleGuideRow('文本样式', [
                _buildPlaceholderChip('**粗体**', '粗体'),
                _buildPlaceholderChip('*斜体*', '斜体'),
                _buildPlaceholderChip('***粗斜体***', '粗斜体'),
                _buildPlaceholderChip('__下划线__', '下划线'),
                _buildPlaceholderChip('~~删除线~~', '删除线'),
              ]),
              SizedBox(height: 8.h),
              _buildStyleGuideRow('字号大小', [
                _buildPlaceholderChip('<small>小字</small>', '小号'),
                _buildPlaceholderChip('<large>大字</large>', '大号'),
                _buildPlaceholderChip('<xl>超大</xl>', '超大'),
              ]),
              SizedBox(height: 8.h),
              _buildStyleGuideRow('对齐方式', [
                _buildPlaceholderChip('[left]左对齐[/left]', '左对齐'),
                _buildPlaceholderChip('[center]居中[/center]', '居中'),
                _buildPlaceholderChip('[right]右对齐[/right]', '右对齐'),
              ]),
              SizedBox(height: 8.h),
              _buildStyleGuideRow('分隔元素', [
                _buildPlaceholderChip('---', '细分隔线'),
                _buildPlaceholderChip('===', '粗分隔线'),
                _buildPlaceholderChip('<br>', '空行'),
              ]),
            ],
          ),
          SizedBox(height: _spacingL.h),
          Divider(color: _highlightBorder),
          SizedBox(height: _spacingM.h),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20.sp, color: _infoColor),
              SizedBox(width: _spacingS.w),
              Text(
                '使用注意事项',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: _infoColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildUsageNote(
            '1. 避免嵌套字号标签',
            '不要混用不同的字号标签，选择一种即可。',
            '❌ 错误: [size=2]<xl>文本</xl>[/size]\n✅ 正确: <xl>文本</xl> 或 [size=2]文本[/size]',
          ),
          SizedBox(height: 8.h),
          _buildUsageNote(
            '2. 字号标签内无需嵌套样式',
            '<xl>、<large>、<small> 标签会自动清理内部的 **、*、~~ 等样式标记，只保留纯文本。',
            '❌ 错误: <xl>**文本**</xl>\n✅ 正确: <xl>文本</xl>\n💡 提示: <xl> 已自带加粗效果',
          ),
          SizedBox(height: 8.h),
          _buildUsageNote(
            '3. 分隔线必须是3个字符',
            '分隔线只识别恰好3个连续的等号或减号。',
            '✅ 正确: === 或 ---\n❌ 错误: ==, ====, =====',
          ),
          SizedBox(height: 8.h),
          _buildUsageNote(
            '4. 推荐的模板示例',
            '标题居中 + 字段左对齐 + 条形码居中',
            '[center]<xl>店铺名称</xl>[/center]\n[center]===[/center]\n[left]**字段:** {{value}}[/left]\n[center]{{barcode}}[/center]',
          ),
        ],
      ),
    );
  }

  Widget _buildUsageNote(String title, String description, String example) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
        border: Border.all(color: _highlightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            description,
            style: TextStyle(fontSize: 12.sp, color: _textSecondary),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: _lightBg2,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Text(
              example,
              style: TextStyle(
                fontSize: 11.sp,
                fontFamily: 'monospace',
                color: _textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleGuideRow(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13.sp,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.h),
        Wrap(spacing: 8.w, runSpacing: 6.h, children: chips),
      ],
    );
  }

  Widget _buildPlaceholderChip(String placeholder, String description) {
    return GestureDetector(
      onTap: () {
        final text = _contentController.text;
        final selection = _contentController.selection;
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          placeholder,
        );
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: selection.start + placeholder.length,
          ),
        );
        _templateContent.value = newText; // 同步更新响应式内容
        _hasUnsavedChanges.value = true;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFFAFAFA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: const Color(0xFFFFD54F).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: _codeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                placeholder,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontFamily: 'monospace',
                  color: _codeColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              description,
              style: TextStyle(
                fontSize: 12.sp,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateEditor() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _borderColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _contentController,
        maxLines: null,
        expands: true,
        style: TextStyle(
          fontSize: 14.sp,
          fontFamily: 'monospace',
          height: 1.6,
          color: _textPrimary,
          letterSpacing: 0.3,
        ),
        decoration: InputDecoration(
          hintText: '请输入小票模板内容...支持使用占位符',
          hintStyle: TextStyle(
            fontSize: 14.sp,
            color: _textDisabled.withOpacity(0.6),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20.w),
        ),
        onChanged: (value) {
          _hasUnsavedChanges.value = true;
          _templateContent.value = value; // 同步更新响应式内容用于预览
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _spacingM.w,
      runSpacing: 12.h,
      children: [
        // 提示信息
        Obx(
          () => _hasUnsavedChanges.value
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10.sp, color: _warningColor),
                    SizedBox(width: _spacingS.w),
                    Text(
                      '有未保存的更改',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: _warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        // 重置按钮
        SizedBox(
          height: 48.h,
          child: OutlinedButton.icon(
            onPressed: () async {
              final shouldReset = await _showResetConfirmDialog();
              if (shouldReset == true) {
                await _loadTemplate();
              }
            },
            icon: Icon(Icons.refresh, size: 20.sp),
            label: Text(
              '重置',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5C6BC0),
              side: BorderSide(
                color: const Color(0xFF5C6BC0).withOpacity(0.3),
                width: 1.5,
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
          ),
        ),
        // 保存按钮
        Obx(
          () => SizedBox(
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: _isSaving.value ? null : _saveTemplate,
              icon: _isSaving.value
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.save_outlined, size: 20.sp),
              label: Text(
                _isSaving.value ? '保存中...' : '保存模板',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
                elevation: 0,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ).copyWith(
                elevation: MaterialStateProperty.resolveWith<double>(
                  (states) {
                    if (states.contains(MaterialState.pressed)) return 8;
                    if (states.contains(MaterialState.hovered)) return 4;
                    return 2;
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.preview_outlined,
                  size: 24.sp,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                '预览效果',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Expanded(child: _buildPreviewContent()),
          SizedBox(height: 20.h),
          _buildTestPrintButton(),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _borderColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Obx(() {
          final mockData = ReceiptPrintData.mock();
          String previewText = _templateContent.value; // 使用响应式变量

          if (previewText.isEmpty) {
            return Center(
              child: Text(
                '暂无内容',
                style: TextStyle(fontSize: 14.sp, color: _textDisabled),
              ),
            );
          }

          final replacements = {
            '{{storeName}}': mockData.storeName,
            '{{operatorName}}': mockData.operatorName,
            '{{storageId}}': mockData.storageId,
            '{{memberId}}': mockData.memberId,
            '{{telephone}}': mockData.telephone,
            '{{numberTickets}}': mockData.numberTickets.toString(),
            '{{printTime}}': _formatDateTime(mockData.printTime),
            '{{barcode}}': mockData.barcode ?? '',
          };

          replacements.forEach((placeholder, value) {
            previewText = previewText.replaceAll(placeholder, value);
          });

          // 使用样式解析器解析富文本
          final spans = ReceiptStyleParser.parse(
            previewText,
            baseFontSize: 13.sp,
          );

          return RichText(
            text: TextSpan(
              children: spans,
              style: TextStyle(
                fontFamily: 'monospace',
                height: 1.5,
                color: _textDark,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTestPrintButton() {
    return Obx(
      () => SizedBox(
        height: 52.h,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isPrinting.value ? null : _testPrint,
          icon: _isPrinting.value
              ? SizedBox(
                  width: 22.w,
                  height: 22.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.print_outlined, size: 22.sp),
          label: Text(
            _isPrinting.value ? '打印中...' : '测试打印',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
            elevation: 0,
            shadowColor: const Color(0xFF4CAF50).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ).copyWith(
            elevation: MaterialStateProperty.resolveWith<double>(
              (states) {
                if (states.contains(MaterialState.pressed)) return 8;
                if (states.contains(MaterialState.hovered)) return 4;
                return 2;
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (_contentController.text.trim().isEmpty) {
      Toast.error(message: '模板内容不能为空');
      return;
    }

    _isSaving.value = true;

    try {
      final template = ReceiptTemplate(
        id: 'template_${_selectedType.value.code}',
        type: _selectedType.value,
        content: _contentController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await _templateService.saveTemplate(template);

      if (success) {
        _hasUnsavedChanges.value = false;
        Toast.success(message: '模板已保存');
      }
    } catch (e) {
      Toast.error(message: '保存失败: $e');
    } finally {
      _isSaving.value = false;
    }
  }

  Future<void> _testPrint() async {
    // 防止重复点击
    if (_isPrinting.value) {
      print('[ReceiptSettings] 测试打印正在进行中，忽略重复点击');
      return;
    }

    if (_hasUnsavedChanges.value) {
      Toast.error(message: '请先保存模板');
      return;
    }

    if (_printerService.selectedPrinter.value == null) {
      Toast.error(message: '未检测到打印机');
      return;
    }

    _isPrinting.value = true;
    print('[ReceiptSettings] 开始测试打印');

    // 🔧 修复：添加超时保护，防止状态永久卡住
    // 即使出现未预期的错误，30秒后也会自动重置状态
    Future.delayed(const Duration(seconds: 30), () {
      if (_isPrinting.value) {
        print('[ReceiptSettings] ⚠️ 检测到打印状态超时，强制重置');
        _isPrinting.value = false;
      }
    });

    try {
      final mockData = ReceiptPrintData.mock();
      final printContent = await _templateService.generatePrintContent(
        _selectedType.value,
        mockData,
      );
      final device = _printerService.selectedPrinter.value!;
      print('[ReceiptSettings] 打印内容生成成功，设备: ${device.displayName}');

      // 检查是否已有权限
      final alreadyHasPermission = await _printerService.hasPermission(device);
      print('[ReceiptSettings] 权限检查结果: $alreadyHasPermission');

      if (!alreadyHasPermission) {
        // 没有权限：异步请求（不阻塞UI）
        print('[ReceiptSettings] 请求USB权限...');
        _printerService.requestPermission(device).then((granted) async {
          if (granted) {
            // 权限已立即授予（之前已授权过）
            print('[ReceiptSettings] 权限已授予，继续打印');
            await _executePrint(device, printContent);
          } else {
            // 权限请求已发起，等待用户在系统弹窗中授权
            // 立即重置按钮状态，让用户可以再次点击
            _isPrinting.value = false;
            Toast.info(message: '正在请求打印机访问权限\n请在弹出的对话框中点击"允许"');
            print('[ReceiptSettings] 等待用户授权，按钮已恢复');
          }
        });
        return; // 立即返回，不阻塞UI
      }

      // 已有权限，直接打印
      await _executePrint(device, printContent);
    } catch (e, stackTrace) {
      print('[ReceiptSettings] 测试打印异常: $e');
      print('[ReceiptSettings] 堆栈跟踪: $stackTrace');
      Toast.error(message: '打印失败: $e');
      _isPrinting.value = false;
    }
  }

  /// 执行实际的打印操作
  Future<void> _executePrint(
    ExternalPrinterDevice device,
    String printContent,
  ) async {
    try {
      print('[ReceiptSettings] 发送打印指令...');
      final result = await _printerService.testPrint(
        device,
        content: printContent,
      );
      print('[ReceiptSettings] 打印结果: ${result.success}, 消息: ${result.message}');

      if (result.success) {
        Toast.success(message: '测试打印已发送');
      } else {
        Toast.error(message: result.message ?? '打印失败');
      }
    } catch (e, stackTrace) {
      print('[ReceiptSettings] 打印执行异常: $e');
      print('[ReceiptSettings] 堆栈跟踪: $stackTrace');
      Toast.error(message: '打印失败: $e');
    } finally {
      _isPrinting.value = false;
      print('[ReceiptSettings] 打印流程结束');
    }
  }

  Future<bool?> _showUnsavedChangesDialog() async {
    return await AppDialog.confirm(
      title: '未保存的更改',
      message: '当前模板有未保存的更改,是否继续?',
      confirmText: '继续',
      barrierDismissible: false,
    );
  }

  Future<bool?> _showResetConfirmDialog() async {
    return await AppDialog.confirm(
      title: '重置模板',
      message: '确定要重置为上次保存的版本吗?',
      confirmText: '重置',
      barrierDismissible: false,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 可拖拽的分隔条组件
  Widget _buildDraggableDivider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          // 获取Row容器的实际宽度（更精确）
          final RenderBox? renderBox =
              _editorRowKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) return;

          final rowWidth = renderBox.size.width;
          if (rowWidth <= 0) return;

          // 计算拖拽增量对应的比例变化
          final dragDelta = details.delta.dx;
          final deltaPercent = (dragDelta / rowWidth) * 100;

          // 计算新的比例
          final newFlex = (_leftPanelFlex.value + deltaPercent)
              .clamp(25.0, 75.0)
              .round();

          // 只在比例真正改变时更新（避免频繁触发rebuild）
          if (newFlex != _leftPanelFlex.value) {
            _leftPanelFlex.value = newFlex;
          }
        },
        child: Container(
          width: 8.w,
          color: Colors.transparent,
          child: Center(
            child: Container(width: 2.w, color: _textDisabled),
          ),
        ),
      ),
    );
  }
}
