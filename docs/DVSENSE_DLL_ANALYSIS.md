# DVSense DLL调用与运行库分析

## 证据范围

本记录基于本机以下一手文件，而不是根据文件名猜测：

- `C:\Program Files (x86)\DvsenseDriver\include`
- `C:\Program Files (x86)\DvsenseDriver\lib`
- `C:\Program Files (x86)\DvsenseDriver\bin`
- `C:\Program Files (x86)\DvsenseDriver\share\DvsenseDriver\Samples`
- `C:\Program Files\Dvsense Insight\DvsenseInsight.exe`
- `C:\Users\chen1\Desktop\DVSenseRealtimeV1\runtime\bin\dvsense_helper.exe`

PE依赖由 Visual Studio `dumpbin /DEPENDENTS` 检查，符号由
`dumpbin /EXPORTS` 和 `/IMPORTS` 检查，参数调用链由 SDK 头文件和官方示例核对。

## helper的实际依赖闭包

`dvsense_helper.exe`的直接导入是：

- `DvsenseBase.dll`
- `DvsenseHal.dll`
- `DvsenseDriver.dll`
- Microsoft C/C++运行库和Windows系统库

继续递归DVSense三件套得到当前版本需要的非系统DLL：

| DLL | 证据 |
| --- | --- |
| `DvsenseBase.dll` | helper直接导入；其自身导入`spdlog.dll`、`fmt.dll` |
| `DvsenseHal.dll` | helper直接导入；其自身导入`DvsenseBase.dll`、`libusb-1.0.dll` |
| `DvsenseDriver.dll` | helper直接导入；其自身导入`DvsenseHal.dll`、`DvsenseBase.dll`和FFmpeg |
| `spdlog.dll`、`fmt.dll` | `DvsenseBase.dll`的非系统依赖 |
| `libusb-1.0.dll` | `DvsenseHal.dll`的非系统依赖 |
| `avcodec-62.dll`、`avformat-62.dll`、`avutil-60.dll`、`swscale-9.dll` | `DvsenseDriver.dll`的非系统依赖 |
| `swresample-6.dll` | `avcodec-62.dll`的非系统依赖 |

因此当前工程复制的运行库清单由
`src/matlab/+app/dvsenseRuntimeFiles.m`集中维护，并由构建脚本从同一SDK版本复制到
`runtime/bin`，与`dvsense_helper.exe`放在同一目录。Windows会优先在helper
所在目录解析这些DLL，不需要修改MATLAB进程的全局`PATH`。

`runtime/bin/dvsense_bridge.dll`不链接DVSense SDK，它只管理helper进程和协议。
这是有意的隔离边界：本机实测将`DvsenseDriver.dll`直接加载进MATLAB后，
SDK在`DvsenseHal.dll`的USB枚举路径触发MATLAB访问冲突；因此最终版不能让
MATLAB直接加载vendor DLL。

Microsoft运行库、`KERNEL32`、`WS2_32`、`IPHLPAPI`、`SETUPAPI`以及
`api-ms-win-*`属于系统或已安装的运行时，不作为DVSense私有DLL复制。

## Insight与helper的差异

对`C:\Program Files\Dvsense Insight\DvsenseInsight.exe`的直接导入确认了：

- DVSense三件套。
- `Qt6Widgets.dll`、`Qt6Gui.dll`、`Qt6Core.dll`。
- 主程序使用`QImage`、`QPixmap`和`QThread`。
- 主程序使用`DvsCamera::getAllToolsInfo`、`getTool`和参数信息类型。
- 主程序使用DVSense事件对象池相关符号。

Insight安装目录还包含OpenCV和FFmpeg库，但主程序的直接导入表没有显示
OpenCV或FFmpeg。它们可能由其他组件或动态加载路径使用，不能据此把它们
复制进MATLAB路径。

特别是Qt DLL必须避免放入MATLAB全局`PATH`：Qt版本或插件目录冲突可能造成
MATLAB GUI加载错误、插件解析错误或进程崩溃。当前helper不创建Qt窗口，
也不需要Insight的Qt/OpenCV显示层。

## 官方参数调整调用链

SDK头文件：

`C:\Program Files (x86)\DvsenseDriver\include\DvsenseHal\camera\tools\CameraTool.h`

确认的接口为：

1. `camera->getAllToolsInfo()`枚举相机实际存在的工具和参数名。
2. `camera->getTool(toolType)`或`camera->getTool(toolName)`取得工具。
3. `tool->getAllParamInfo()`取得参数基本信息和类型。
4. 用对应类型的`getParamInfo(name, info)`读取范围、选项和默认值。
5. 用类型对应的`getParam(name, value)`读取当前值。
6. 用`setParam(name, value)`写入，检查返回的`bool`。
7. 写入后再次`getParam`回读确认。

官方示例也直接验证了这种方式：

- `DvsenseLiveViewerSample\DsLiveViewerSample.cpp`使用ROI工具的
  `x`、`y`、`width`、`height`、`enable`。
- 同一示例给出了Bias参数`bias_diff_on`和`bias_diff_off`的设置示例。
- `DvsenseEthCameraViewer\DsEthCameraViewer.cpp`给出了事件率控制的
  `max_event_rate`和`enable`设置示例。
- `DvsenseSyncViewerSample\DVSyncViewer.cpp`使用Sync工具的字符串枚举参数。

因此后续参数面板应当动态生成，不能把所有相机都假定成同一组字段。当前
helper已经通过`getAllToolsInfo`和`getAllParamInfo`返回工具/参数元数据；
`toolparameters`协议返回以下结构化字段：

- `tool`、`name`、`type`
- `details`、`current`
- `min`、`max`、`defaultValue`
- `unit`、`options`

`setparam(tool, name, type, value)`已经按`INT/FLOAT/BOOL/ENUM/STRING`分派。
MATLAB在命令入队前根据上述元数据校验一次；helper再次从当前相机的
`getParamInfo`取得约束并校验，随后调用`setParam`，最后用`getParam`回读。
界面显示的是回读值，而不是假定写入值已经生效。

2026-08-14在当前DVSLume上的真机验证结果为26个详细参数。把
`Biases/bias_diff`的当前值`0`原样写回后，SDK回读值仍为`0`。

需要注意，当前SDK的部分Bias参数把`defaultValue`报告为与公开`min/max`
不同语义的数值，例如`bias_diff`范围为`[-25, 23]`，但默认字段为`77`。
因此合法性判断只使用SDK返回的`min/max`或`options`，不使用默认值反推范围。
该不一致来自SDK元数据，工程不擅自修正或猜测其含义。

## 当前工程的借鉴关系

- 官方回调线程写事件；当前helper保留固定容量事件缓冲。
- 官方显示使用固定刷新率和颜色索引；当前helper在回调内维护官方灰底、白色
  ON、黑色OFF的双缓冲。
- 官方使用对象池复用事件容器；当前helper采用固定容量预分配数组并覆盖最新批次。
- 官方显示线程和设备工作线程分离；当前MATLAB GUI通过事件泵与helper通信，
  相机SDK仍留在独立helper进程。

## 扩展规则

后续只有在`dumpbin /DEPENDENTS`确认新增功能引入新DLL时，才把它加入
`dvsenseRuntimeFiles.m`并同步重新构建、启动验证和文档。不要直接复制
Insight整目录，也不要把Qt/OpenCV/FFmpeg作为“可能需要”全部加入MATLAB
搜索路径。供应商DLL的再分发许可仍以DVSense安装包和SDK许可为准。
