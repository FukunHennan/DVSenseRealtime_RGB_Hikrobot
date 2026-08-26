# DVSense官方显示链路分析

## SDK源码可确认的行为

本机SDK示例：

`C:\Program Files (x86)\DvsenseDriver\share\DvsenseDriver\Samples\DvsenseLiveViewerSample\DsLiveViewerSample.cpp`

- 相机事件通过`addEventsStreamHandleCallback`进入解码回调。
- 回调直接把事件写入显示缓冲，不为显示复制完整事件列表。
- 显示使用两个固定大小图像缓冲。
- UI取帧时只在锁内交换缓冲并清空新的写缓冲，图像复制在锁外完成。
- 示例显示刷新率为25 FPS。
- 背景为RGB `[112 112 112]`，ON事件为白色，OFF事件为黑色。
- SDK示例使用OpenCV显示，但双缓冲模式不依赖OpenCV本身。

## Insight安装内容可确认的技术栈

`C:\Program Files\Dvsense Insight`包含：

- Qt 6 Widgets、GUI和Network运行库。
- OpenCV core、imgproc、highgui、videoio和imgcodecs。
- FFmpeg avcodec、avformat、avutil、swscale和swresample。
- DvsenseBase、DvsenseHal和DvsenseDriver。

这些依赖说明Insight具备Qt界面、OpenCV图像处理和FFmpeg媒体输出能力，但不能仅凭DLL列表断言其内部具体算法。

对`DvsenseInsight.exe`导入表的进一步检查确认：

- 主程序直接依赖DvsenseDriver、DvsenseHal、DvsenseBase和Qt 6。
- 主程序直接导入`QImage`创建、填充、逐像素写入和`QPixmap::fromImage`。
- 主程序直接导入`QThread`，显示与设备工作存在独立线程边界。
- 主程序直接导入`DvsCamera::getAllToolsInfo`、`getTool`以及整数、浮点、布尔和枚举参数信息类型。
- 主程序直接使用`DsObjectPool<std::vector<Event2D>>`，说明事件容器通过对象池复用。
- 主程序没有直接导入OpenCV或FFmpeg；安装目录中的这些库可能由其他DVSense组件动态使用，不能据此认定DVS显示主路径依赖OpenCV。
- helper的递归运行库清单和`dumpbin`证据单独记录在`docs/DVSENSE_DLL_ANALYSIS.md`；
  当前构建只复制helper闭包，不复制Insight的Qt运行库。

## 当前工程的对应实现

- helper事件回调保留最新事件批次给识别。
- 同一回调把事件写入独立的固定大小`uint8`显示缓冲；多个回调批次会累积到下一次显示交换。
- `readframe`命令交换双缓冲、返回累积帧，并清空下一周期的生产缓冲。
- `DVSenseSession`通过bridge C ABI读取调用方缓冲，并在MATLAB中把原生行优先
  `uint8`帧重排为列优先矩阵。正式路径不依赖MEX读取显示帧。
- MATLAB界面只更新`CData`，不再根据事件重新生成显示帧。
- 显示与识别使用独立节奏：识别保留最新事件批次，显示按25 Hz交换并累积一个显示周期；显示阻塞不会扩展事件缓存。
- `DVSenseCameraSource`析构时强制关闭helper和相机，减少异常退出后的设备遗留占用。
- helper通过`getAllToolsInfo`读取当前相机实际支持的工具和参数名称，与Insight的运行时枚举方式一致。
- 参数调整应沿用官方链路：`getTool` -> `getAllParamInfo` ->
  `getParamInfo/getParam` -> 按类型`setParam` -> 回读确认；不要根据界面标签
  猜测参数名或范围。
- MATLAB GUI每轮采集都会泵回调，停止按钮发送有序停止命令；资源关闭顺序为
  recorder、RAW、source/helper、viewer。

## 后续可确认项目

SDK还公开以下硬件工具：

- `TOOL_ANTI_FLICKER`
- `TOOL_EVENT_TRAIL_FILTER`
- `TOOL_EVENT_RATE_CONTROL`
- `TOOL_ROI`
- `TOOL_BIAS`

工具参数应通过`CameraTool::getAllParamInfo`和`getParamInfo`在实际DVSLume上查询，不应猜测参数名称、范围或默认值。

当前DVSLume真机枚举结果：

- Biases: `bias_fo`, `bias_hpf`, `bias_diff_on`, `bias_diff`, `bias_diff_off`, `bias_refr`
- TriggerIn: `enable`
- Sync: `mode`
- AntiFlicker: `duty_cycle`, `enable`, `fliter_mode`, `high_frequency`, `low_frequency`, `start_threshold`, `stop_threshold`
- EventTrailFilter: `enable`, `threshold`, `type`
- EventRateControl: `enable`, `max_event_rate`
- ROI摘要参数名: `enable`, `mode`, `x`, `y`, `x_width`, `y_height`

当前SDK存在元数据不一致：`getAllToolsInfo`的ROI摘要列出`x_width/y_height`，但`CameraTool::getAllParamInfo`返回的实际可读写参数为`width/height`。当前实现以详细参数表为准，并逐项检查写入结果。

## 参数控件实现

参数页在连接相机后使用详细参数表动态生成控件：

- `INT/FLOAT`使用带SDK范围限制的数值框。
- `BOOL`使用复选框。
- `ENUM`使用SDK选项生成下拉框。
- `STRING`使用文本框。
- ROI仍保留适合矩形联动的专用控件。

写入链路为GUI校验、命令队列、source校验、helper校验、SDK `setParam`、
SDK `getParam`回读。任一层失败都会保留采集循环，并把错误显示在对应参数行。

2026-08-14真机详细枚举共26项：

| 工具 | 参数 |
| --- | --- |
| Biases | `bias_diff`, `bias_diff_off`, `bias_diff_on`, `bias_fo`, `bias_hpf`, `bias_refr` |
| TriggerIn | `enable` |
| Sync | `mode`，选项为`STANDALONE`, `MASTER`, `SLAVE` |
| AntiFlicker | `duty_cycle`, `enable`, `fliter_mode`, `high_frequency`, `low_frequency`, `start_threshold`, `stop_threshold` |
| EventTrailFilter | `enable`, `threshold`, `type` |
| EventRateControl | `enable`, `max_event_rate` |
| ROI | `enable`, `height`, `mode`, `width`, `x`, `y` |

这些名称，包括SDK中的`fliter_mode`拼写，均保持设备实际返回值，不在应用层
重命名。参数范围、单位和枚举选项也在每次连接时读取，不固化为工程常量。
