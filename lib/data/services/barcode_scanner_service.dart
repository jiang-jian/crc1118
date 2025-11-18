import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/barcode_scanner_model.dart';

/// 条码扫描器服务
/// 管理USB HID扫描器设备的连接、扫描和数据接收
class BarcodeScannerService extends GetxService {
  static const MethodChannel _channel =
      MethodChannel('com.holox.ailand_pos/barcode_scanner');
  
  // 公开channel用于键盘事件处理
  MethodChannel get channel => _channel;

  // ========== 响应式状态 ==========
  
  /// 是否正在扫描设备
  final RxBool isScanning = false.obs;

  /// 检测到的扫描器设备列表
  final RxList<BarcodeScannerDevice> detectedScanners =
      <BarcodeScannerDevice>[].obs;

  /// 当前选中的扫描器设备
  final Rx<BarcodeScannerDevice?> selectedScanner =
      Rx<BarcodeScannerDevice?>(null);

  /// 最新扫描的数据
  final Rx<ScanResult?> scanData = Rx<ScanResult?>(null);

  /// 最后一次错误信息
  final Rx<String?> lastError = Rx<String?>(null);

  /// 是否正在监听扫码（扫描器已就绪）
  final RxBool isListening = false.obs;

  /// 最新连接的设备ID（用于高亮显示）
  final Rx<String?> latestDeviceId = Rx<String?>(null);

  /// 最后一次扫码的设备ID（用于高亮显示）
  final Rx<String?> lastScanDeviceId = Rx<String?>(null);

  /// 调试日志列表
  final RxList<String> debugLogs = <String>[].obs;

  /// 调试日志面板展开状态
  final RxBool debugLogExpanded = false.obs;

  // ========== 生命周期 ==========

  /// 初始化服务
  Future<BarcodeScannerService> init() async {
    _setupMethodCallHandler();
    _addLog('📱 扫码服务初始化完成');
    return this;
  }

  @override
  void onInit() {
    super.onInit();
    _addLog('📱 扫码服务已就绪');
  }

  @override
  void onClose() {
    stopListening();
    _addLog('🔌 扫码服务已关闭');
    super.onClose();
  }

  // ========== 公共方法 ==========

  /// 扫描USB扫描器设备
  Future<void> scanUsbScanners() async {
    try {
      isScanning.value = true;
      lastError.value = null;
      _addLog('🔍 开始扫描USB扫描器设备...');

      final List<dynamic> devices =
          await _channel.invokeMethod('scanUsbScanners');

      detectedScanners.value =
          devices.map((d) => BarcodeScannerDevice.fromMap(d)).toList();

      _addLog('✓ 扫描完成，发现 ${detectedScanners.length} 个设备');

      // 如果找到设备，记录最新设备ID
      if (detectedScanners.isNotEmpty) {
        latestDeviceId.value = detectedScanners.first.deviceId;
        _addLog('📍 最新设备: ${detectedScanners.first.deviceName}');

        // 自动选择第一个已连接的设备
        final connectedDevice = detectedScanners
            .firstWhereOrNull((device) => device.isConnected);
        if (connectedDevice != null) {
          selectedScanner.value = connectedDevice;
          _addLog('✓ 自动选择已连接设备: ${connectedDevice.deviceName}');
          // 自动开始监听
          await startListening();
        }
      } else {
        _addLog('⚠️ 未发现扫描器设备');
      }
    } catch (e) {
      lastError.value = '扫描失败: $e';
      _addLog('✗ 扫描失败: $e');
    } finally {
      isScanning.value = false;
    }
  }

  /// 请求USB设备权限
  Future<bool> requestPermission(String deviceId) async {
    try {
      _addLog('🔑 请求设备权限: $deviceId');
      final bool granted = await _channel.invokeMethod(
        'requestPermission',
        {'deviceId': deviceId},
      );

      if (granted) {
        _addLog('✓ 权限已授予');
        // 权限授予后重新扫描以更新连接状态
        await scanUsbScanners();
      } else {
        _addLog('✗ 权限被拒绝');
      }

      return granted;
    } catch (e) {
      lastError.value = '权限请求失败: $e';
      _addLog('✗ 权限请求失败: $e');
      return false;
    }
  }

  /// 开始监听扫码输入
  Future<void> startListening() async {
    try {
      if (selectedScanner.value == null) {
        lastError.value = '请先选择扫描器设备';
        _addLog('⚠️ 未选择设备，无法开始监听');
        return;
      }

      if (!selectedScanner.value!.isConnected) {
        lastError.value = '设备未连接，请先授予USB权限';
        _addLog('⚠️ 设备未连接');
        return;
      }

      _addLog('👂 开始监听扫码输入...');
      await _channel.invokeMethod(
        'startListening',
        {'deviceId': selectedScanner.value!.deviceId},
      );

      isListening.value = true;
      lastError.value = null;
      _addLog('✓ 监听已启动，等待扫码...');
    } catch (e) {
      lastError.value = '启动监听失败: $e';
      _addLog('✗ 启动监听失败: $e');
      isListening.value = false;
    }
  }

  /// 停止监听扫码输入
  Future<void> stopListening() async {
    try {
      if (isListening.value) {
        _addLog('🔇 停止监听扫码输入...');
        await _channel.invokeMethod('stopListening');
        isListening.value = false;
        _addLog('✓ 监听已停止');
      }
    } catch (e) {
      _addLog('✗ 停止监听失败: $e');
    }
  }

  /// 清除扫码数据
  void clearScanData() {
    scanData.value = null;
    lastError.value = null;
    lastScanDeviceId.value = null;
    _addLog('🧹 已清除扫码数据');
  }

  /// 清除调试日志
  void clearLogs() {
    debugLogs.clear();
    _addLog('📋 日志已清空');
  }

  // ========== 私有方法 ==========

  /// 设置方法调用处理器（接收原生层回调）
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onScanResult':
          _handleScanResult(call.arguments);
          break;
        case 'onError':
          _handleError(call.arguments);
          break;
        case 'onDeviceAttached':
          _handleDeviceAttached(call.arguments);
          break;
        case 'onDeviceDetached':
          _handleDeviceDetached(call.arguments);
          break;
        default:
          _addLog('⚠️ 未知方法调用: ${call.method}');
      }
    });
  }

  /// 处理扫码结果
  void _handleScanResult(dynamic arguments) {
    try {
      final result = ScanResult.fromMap(arguments as Map<dynamic, dynamic>);
      scanData.value = result;
      lastError.value = null;

      // 记录扫码设备ID
      if (selectedScanner.value != null) {
        lastScanDeviceId.value = selectedScanner.value!.deviceId;
      }

      _addLog('✓ 扫码成功: ${result.type}');
      _addLog('  内容: ${result.content}');
      _addLog('  长度: ${result.length} 字符');
      _addLog('  时间: ${_formatLogTimestamp(result.timestamp)}');
      _addLog('  有效: ${result.isValid ? "是" : "否"}');
      if (result.rawData != null && result.rawData != result.content) {
        _addLog('  原始: ${result.rawData}');
      }
    } catch (e) {
      _addLog('✗ 处理扫码结果失败: $e');
    }
  }

  /// 处理错误
  void _handleError(dynamic arguments) {
    try {
      final errorMsg = arguments.toString();
      lastError.value = errorMsg;
      _addLog('✗ 错误: $errorMsg');
    } catch (e) {
      _addLog('✗ 处理错误失败: $e');
    }
  }

  /// 处理设备连接
  void _handleDeviceAttached(dynamic arguments) {
    try {
      _addLog('🔌 设备已连接');
      // 重新扫描设备列表
      scanUsbScanners();
    } catch (e) {
      _addLog('✗ 处理设备连接失败: $e');
    }
  }

  /// 处理设备断开
  void _handleDeviceDetached(dynamic arguments) {
    try {
      _addLog('🔌 设备已断开');
      // 如果是当前选中的设备断开，清除选择
      if (selectedScanner.value != null) {
        selectedScanner.value = null;
        isListening.value = false;
      }
      // 重新扫描设备列表
      scanUsbScanners();
    } catch (e) {
      _addLog('✗ 处理设备断开失败: $e');
    }
  }

  /// 添加调试日志
  void _addLog(String message) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    debugLogs.insert(0, '[$formattedTime] $message');

    // 限制日志数量，保留最近100条
    if (debugLogs.length > 100) {
      debugLogs.removeRange(100, debugLogs.length);
    }
  }

  /// 格式化日志时间戳（用于扫描结果）
  String _formatLogTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
  }
}
