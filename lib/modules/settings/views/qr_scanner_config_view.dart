import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/services/barcode_scanner_service.dart';

/// 二维码/条形码扫描仪配置页面
/// 三列布局：左侧设备信息 | 中间扫描提示 | 右侧数据展示
class QrScannerConfigView extends StatefulWidget {
  const QrScannerConfigView({super.key});

  @override
  State<QrScannerConfigView> createState() => _QrScannerConfigViewState();
}

class _QrScannerConfigViewState extends State<QrScannerConfigView>
    with SingleTickerProviderStateMixin {
  // 获取扫描器服务
  final BarcodeScannerService _scannerService = Get.find<BarcodeScannerService>();

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // 键盘焦点节点
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 自动扫描设备
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerService.scanUsbScanners();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Row(
          children: [
            // 左列：设备信息 (30%)
            Expanded(
              flex: 30,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 40.h),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  border: Border(
                    right: BorderSide(color: AppTheme.borderColor, width: 1.w),
                  ),
                ),
                child: _buildDeviceInfoSection(),
              ),
            ),

            // 中列：扫描提示 (32%)
            Expanded(
              flex: 32,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 56.w, vertical: 40.h),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  border: Border(
                    right: BorderSide(color: AppTheme.borderColor, width: 1.w),
                  ),
                ),
                child: _buildScanningSection(),
              ),
            ),

            // 右列：数据展示 (38%)
            Expanded(
              flex: 38,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 40.h),
                color: Colors.white,
                child: _buildDataDisplaySection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理键盘事件
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // 将键盘事件发送到原生层处理
      final keyCode = event.logicalKey.keyId;
      _scannerService.channel.invokeMethod('handleKeyEvent', {
        'keyCode': keyCode,
        'action': 0, // ACTION_DOWN
      });
    }
  }

  /// 构建左列：设备信息区
  Widget _buildDeviceInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          '设备信息',
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),

        SizedBox(height: 40.h),

        // 扫描设备按钮
        _buildScanDeviceButton(),

        SizedBox(height: 40.h),

        // 设备列表或空状态
        Expanded(
          child: Obx(() {
            if (_scannerService.isScanning.value) {
              return _buildScanningDevicesState();
            } else if (_scannerService.detectedScanners.isEmpty) {
              return _buildNoDeviceState();
            } else {
              return _buildDevicesList();
            }
          }),
        ),
      ],
    );
  }

  /// 扫描设备按钮
  Widget _buildScanDeviceButton() {
    return Obx(() {
      final isScanning = _scannerService.isScanning.value;
      return SizedBox(
        height: 56.h,
        child: ElevatedButton.icon(
          onPressed: isScanning ? null : () => _scannerService.scanUsbScanners(),
          icon: isScanning
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.refresh, size: 22.sp),
          label: Text(
            isScanning ? '扫描中...' : '扫描USB设备',
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
          ),
        ),
      );
    });
  }

  /// 扫描设备中状态
  Widget _buildScanningDevicesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50.w,
            height: 50.h,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5B544)),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            '扫描中...',
            style: TextStyle(fontSize: 16.sp, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  /// 无设备状态
  Widget _buildNoDeviceState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner_outlined,
            size: 60.sp,
            color: const Color(0xFFBDC3C7),
          ),
          SizedBox(height: 16.h),
          Text(
            '未检测到扫描器',
            style: TextStyle(fontSize: 16.sp, color: AppTheme.textTertiary),
          ),
          SizedBox(height: 8.h),
          Text(
            '请连接USB扫描器设备',
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFFBDC3C7)),
          ),
        ],
      ),
    );
  }

  /// 设备列表
  Widget _buildDevicesList() {
    return Obx(() {
      final devices = _scannerService.detectedScanners;
      final selectedDevice = _scannerService.selectedScanner.value;

      return ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final isSelected = selectedDevice?.deviceId == device.deviceId;
          final isConnected = device.isConnected;

          return _buildDeviceListItem(
            device: device,
            isSelected: isSelected,
            isConnected: isConnected,
            onTap: () async {
              if (!isConnected) {
                // 请求权限
                final granted = await _scannerService.requestPermission(device.deviceId);
                
                if (granted) {
                  // 授权成功后，等待设备列表更新
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  // 自动选择该设备（从更新后的列表中获取）
                  final updatedDevice = _scannerService.detectedScanners
                      .firstWhereOrNull((d) => d.deviceId == device.deviceId);
                  
                  if (updatedDevice != null && updatedDevice.isConnected) {
                    _scannerService.selectedScanner.value = updatedDevice;
                    await _scannerService.startListening();
                    
                    // 显示成功提示
                    Get.snackbar(
                      '授权成功',
                      '设备 "${updatedDevice.deviceName}" 已连接并开始监听',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.successColor.withValues(alpha: 0.9),
                      colorText: Colors.white,
                      icon: Icon(Icons.check_circle, color: Colors.white),
                      duration: const Duration(seconds: 2),
                    );
                  }
                }
              } else {
                // 选择设备并开始监听
                _scannerService.selectedScanner.value = device;
                await _scannerService.startListening();
              }
            },
          );
        },
      );
    });
  }

  /// 设备列表项
  Widget _buildDeviceListItem({
    required device,
    required bool isSelected,
    required bool isConnected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isConnected ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
                width: isSelected ? 2.w : 1.w,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 24.sp,
                      color: isConnected
                          ? AppTheme.primaryColor
                          : AppTheme.textTertiary,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        device.deviceName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? AppTheme.successColor.withValues(alpha: 0.1)
                            : AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.borderRadiusSmall),
                      ),
                      child: Text(
                        isConnected ? '已连接' : '未连接',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ),
                    ),
                    // 授权按钮（仅在未连接时显示）
                    if (!isConnected) ..[
                      SizedBox(width: 12.w),
                      SizedBox(
                        height: 32.h,
                        child: ElevatedButton.icon(
                          onPressed: onTap,
                          icon: Icon(Icons.vpn_key, size: 16.sp),
                          label: Text(
                            '授权',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 0,
                            ),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  '设备ID: ${device.deviceId}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.textTertiary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (device.manufacturer != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '制造商: ${device.manufacturer}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
                // 未连接时的提示信息
                if (!isConnected) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.sp,
                          color: AppTheme.warningColor,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            '点击右侧「授权」按钮以连接设备',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.warningColor,
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
        ),
      ),
    );
  }

  /// 构建中列：扫描提示区
  Widget _buildScanningSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '扫描器配置',
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),

        SizedBox(height: 60.h),

        _buildScannerIcon(),

        SizedBox(height: 56.h),

        _buildStatusText(),

        SizedBox(height: 40.h),

        Obx(() {
          final scanData = _scannerService.scanData.value;
          if (scanData != null) {
            return _buildActionButton();
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  /// 扫描器图标（带动画）
  Widget _buildScannerIcon() {
    return Obx(() {
      final isListening = _scannerService.isListening.value;
      final scanData = _scannerService.scanData.value;
      final lastError = _scannerService.lastError.value;

      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isListening && scanData == null ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 220.w,
              height: 220.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getStatusGradientColors(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28.r),
                boxShadow: [
                  BoxShadow(
                    color:
                        _getStatusGradientColors()[0].withValues(alpha: 0.3),
                    blurRadius: 35,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _getStatusIcon(),
                    size: 110.sp,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  /// 状态文本和提示
  Widget _buildStatusText() {
    return Obx(() {
      final statusInfo = _getStatusInfo();

      return Column(
        children: [
          Icon(
            statusInfo['secondaryIcon'],
            size: 42.sp,
            color: statusInfo['color'],
          ),
          SizedBox(height: 18.h),
          Text(
            statusInfo['text'],
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: statusInfo['color'],
            ),
            textAlign: TextAlign.center,
          ),
          if (statusInfo['hint'] != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: (statusInfo['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: (statusInfo['color'] as Color).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                statusInfo['hint'],
                style: TextStyle(
                  fontSize: 15.sp,
                  color: statusInfo['color'],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      );
    });
  }

  /// 操作按钮
  Widget _buildActionButton() {
    return SizedBox(
      width: 200.w,
      height: 52.h,
      child: ElevatedButton.icon(
        onPressed: () {
          _scannerService.clearScanData();
        },
        icon: Icon(Icons.refresh, size: 20.sp),
        label: Text(
          '继续扫描',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 构建右列：数据展示区
  Widget _buildDataDisplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 扫描数据标题
        Text(
          '扫描数据',
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),

        SizedBox(height: 40.h),

        // 扫描数据展示区（上半部分）
        Expanded(
          flex: 5,
          child: Obx(() {
            final scanData = _scannerService.scanData.value;
            return scanData != null
                ? _buildScannedDataDisplay(scanData)
                : _buildDataPlaceholder();
          }),
        ),

        SizedBox(height: 32.h),

        // 调试日志区（下半部分）
        Expanded(
          flex: 5,
          child: _buildDebugLogPanel(),
        ),
      ],
    );
  }

  /// 数据占位符
  Widget _buildDataPlaceholder() {
    return Obx(() {
      final isListening = _scannerService.isListening.value;
      return Center(
        child: Container(
          padding: EdgeInsets.all(40.w),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGrey,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isListening
                    ? Icons.qr_code_scanner
                    : Icons.qr_code_2_outlined,
                size: 80.sp,
                color: const Color(0xFFBDC3C7),
              ),
              SizedBox(height: 20.h),
              Text(
                isListening ? '准备就绪，等待扫码...' : '请先选择扫描器',
                style: TextStyle(
                  fontSize: 18.sp,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 扫描数据展示
  Widget _buildScannedDataDisplay(scanResult) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(28.w),
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
          border: Border.all(
            color: AppTheme.successColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius:
                        BorderRadius.circular(AppTheme.borderRadiusSmall),
                  ),
                ),
                SizedBox(width: 14.w),
                Text(
                  '扫描结果',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    _scannerService.clearScanData();
                  },
                  icon: Icon(Icons.clear, size: 20.sp),
                  tooltip: '清除数据',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppTheme.textTertiary,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            _buildDataRow('数据类型', scanResult.type),
            SizedBox(height: 18.h),
            _buildDataRow('扫描内容', scanResult.content),
            SizedBox(height: 18.h),
            _buildDataRow('数据长度', '${scanResult.length} 字符'),
            SizedBox(height: 18.h),
            _buildDataRow('扫描时间', _formatTimestamp(scanResult.timestamp)),

            SizedBox(height: 24.h),

            // 成功标识
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20.sp,
                    color: AppTheme.successColor,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    '扫描成功',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 数据行
  Widget _buildDataRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: AppTheme.spacingDefault),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ========== 辅助方法 ==========

  /// 获取状态渐变色
  List<Color> _getStatusGradientColors() {
    final scanData = _scannerService.scanData.value;
    final lastError = _scannerService.lastError.value;
    final isListening = _scannerService.isListening.value;

    if (scanData != null) {
      return [
        AppTheme.successColor,
        AppTheme.successColor.withValues(alpha: 0.8),
      ];
    } else if (lastError != null) {
      return [
        const Color(0xFFE74C3C),
        AppTheme.errorColor.withValues(alpha: 0.8),
      ];
    } else if (isListening) {
      return [
        AppTheme.infoColor,
        AppTheme.infoColor.withValues(alpha: 0.8),
      ];
    } else {
      return [
        AppTheme.textTertiary,
        AppTheme.textTertiary.withValues(alpha: 0.8),
      ];
    }
  }

  /// 获取状态图标
  IconData _getStatusIcon() {
    final scanData = _scannerService.scanData.value;
    final lastError = _scannerService.lastError.value;
    final isListening = _scannerService.isListening.value;

    if (scanData != null) {
      return Icons.check_circle;
    } else if (lastError != null) {
      return Icons.error;
    } else if (isListening) {
      return Icons.qr_code_scanner;
    } else {
      return Icons.qr_code_2;
    }
  }

  /// 获取状态信息
  Map<String, dynamic> _getStatusInfo() {
    final scanData = _scannerService.scanData.value;
    final lastError = _scannerService.lastError.value;
    final isListening = _scannerService.isListening.value;
    final selectedScanner = _scannerService.selectedScanner.value;

    if (scanData != null) {
      return {
        'text': '✓ 扫描成功',
        'color': AppTheme.successColor,
        'secondaryIcon': Icons.check_circle,
        'hint': null,
      };
    } else if (lastError != null) {
      return {
        'text': '扫描失败',
        'color': const Color(0xFFE74C3C),
        'secondaryIcon': Icons.error,
        'hint': '💡 $lastError',
      };
    } else if (selectedScanner == null) {
      return {
        'text': '请先选择扫描器设备',
        'color': AppTheme.textTertiary,
        'secondaryIcon': Icons.touch_app,
        'hint': '💡 点击左侧设备列表中的扫描器',
      };
    } else if (!isListening) {
      return {
        'text': '设备就绪，启动监听中...',
        'color': AppTheme.infoColor,
        'secondaryIcon': Icons.sync,
        'hint': null,
      };
    } else {
      return {
        'text': '准备就绪，请扫描条码...',
        'color': AppTheme.infoColor,
        'secondaryIcon': Icons.qr_code_scanner,
        'hint': '将条形码或二维码对准扫描器感应区',
      };
    }
  }

  /// 格式化时间戳
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// 构建调试日志面板
  Widget _buildDebugLogPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(color: AppTheme.borderColor, width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 日志标题栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.borderRadiusMedium),
                topRight: Radius.circular(AppTheme.borderRadiusMedium),
              ),
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1.w),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 22.sp,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: 12.w),
                Text(
                  '调试日志',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                // 日志数量
                Obx(() {
                  final logCount = _scannerService.debugLogs.length;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '$logCount 条',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
                SizedBox(width: 16.w),
                // 清空按钮
                SizedBox(
                  height: 36.h,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _scannerService.clearLogs();
                    },
                    icon: Icon(Icons.delete_outline, size: 18.sp),
                    label: Text(
                      '清空',
                      style: TextStyle(fontSize: 15.sp),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      side: BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 日志内容区（可滚动）
          Expanded(
            child: Obx(() {
              final logs = _scannerService.debugLogs;
              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48.sp,
                        color: AppTheme.textTertiary,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        '暂无日志记录',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '扫描操作日志将显示在此处',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.textTertiary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: logs.length,
                separatorBuilder: (context, index) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildLogItem(log);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 构建单条日志项
  Widget _buildLogItem(String log) {
    // 解析日志格式: [HH:mm:ss] message
    final hasTimestamp = log.startsWith('[');
    String timestamp = '';
    String message = log;

    if (hasTimestamp) {
      final timestampEnd = log.indexOf(']');
      if (timestampEnd != -1) {
        timestamp = log.substring(1, timestampEnd);
        message = log.substring(timestampEnd + 2);
      }
    }

    // 判断日志类型（根据emoji或关键词）
    Color logColor = AppTheme.textSecondary;
    Color bgColor = Colors.white;
    IconData? iconData;

    if (message.contains('✓') || message.contains('成功')) {
      logColor = AppTheme.successColor;
      bgColor = AppTheme.successColor.withOpacity(0.05);
      iconData = Icons.check_circle_outline;
    } else if (message.contains('✗') || message.contains('失败') || message.contains('错误')) {
      logColor = AppTheme.errorColor;
      bgColor = AppTheme.errorColor.withOpacity(0.05);
      iconData = Icons.error_outline;
    } else if (message.contains('⚠️') || message.contains('警告')) {
      logColor = AppTheme.warningColor;
      bgColor = AppTheme.warningColor.withOpacity(0.05);
      iconData = Icons.warning_amber_outlined;
    } else if (message.contains('🔍') || message.contains('扫描')) {
      logColor = AppTheme.infoColor;
      bgColor = AppTheme.infoColor.withOpacity(0.05);
      iconData = Icons.search;
    } else if (message.contains('📱') || message.contains('🔌')) {
      logColor = AppTheme.primaryColor;
      bgColor = AppTheme.primaryColor.withOpacity(0.05);
      iconData = Icons.devices;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: logColor.withOpacity(0.2), width: 1.w),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
          if (iconData != null) ..[
            Icon(
              iconData,
              size: 18.sp,
              color: logColor,
            ),
            SizedBox(width: 12.w),
          ],

          // 时间戳
          if (hasTimestamp) ..[
            Text(
              timestamp,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(width: 12.w),
          ],

          // 日志内容
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14.sp,
                color: logColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
