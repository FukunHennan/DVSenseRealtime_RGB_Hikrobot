# DVSense GUI 与底层命令接口

## 边界

`ui.WorkbenchViewer` 只负责界面和用户动作，不直接调用相机、helper
或 SDK。所有控件动作都转换为版本化事件，再由
`ui.internal.mapControlEvent` 按 SDK 参数元数据校验，最后进入
`ui.internal.CommandMailbox`。

```text
控件回调
  -> version=1 UI event
  -> mapControlEvent(event, parameters)
  -> CommandMailbox.push(command)
  -> app.run.consumeCommands()
  -> camera.DVSenseCameraSource / camera.DVSenseSession
  -> SDK 写入与 readback
  -> viewer.setToolParameterState(index, current)
```

相机所有权仍然属于 `camera.DVSenseCameraSource` 和
`camera.DVSenseSession`。GUI 关闭、参数窗口关闭或分析窗口关闭都不能
直接释放相机。

## 控件事件

事件必须包含 `version=1`、`sequence`、`type` 和 `payload`：

```matlab
event = struct( ...
    "version",1, ...
    "sequence",sequence, ...
    "type","setToolParameter", ...
    "payload",struct( ...
        "index",index, ...
        "tool","Biases", ...
        "name","bias_diff", ...
        "value",value));
```

支持的事件类型：

- `start`
- `stop`
- `startRecording`
- `stopRecording`
- `showAnalysis`
- `hideAnalysis`
- `setOverlayVisible`
- `setRefreshHz`
- `setROI`
- `setToolParameter`
- `connectRgb`
- `disconnectRgb`
- `setRgbExposureUs`

## 命令邮箱

`CommandMailbox` 是有限队列，默认容量为 64：

- `setRefreshHz` 只保留最新值；
- 同一个 `tool/name` 的参数写入只保留最新值；
- `start`、`stop`、录制命令不会被静默丢弃；
- 队列满时抛出 `DVSense:CommandMailboxFull`；
- `consume()` 返回当前命令并立即清空队列。

UI 回调不等待相机写入，也不在回调内重试连接。

## 参数合法性

`setToolParameter` 必须先按索引找到 SDK 参数，并确认 `tool/name` 完全匹配。
随后调用 `camera.validateToolParameter`：

- `INT` / `FLOAT` 检查有限标量和 SDK min/max；
- `BOOL` 只接受逻辑值或 `true/false`；
- `ENUM` 只接受 SDK 返回的 options；
- 未知类型直接拒绝。

界面上的滑条只是第一层限制，MATLAB 命令映射和底层 SDK 仍然会再次校验。
只有 SDK 写入成功并 readback 后，参数才显示为已应用。

## 状态更新

显示帧不进入 HTML 或命令邮箱。`FrameSurface` 持有一个固定图像句柄，仅更新
`CData`，并使用官方颜色：

```text
1 -> RGB [112 112 112]
2 -> RGB [255 255 255]
3 -> RGB [0 0 0]
```

UIAxes 使用 `CDataMapping="scaled"` 和 `CLim=[1 3]`，避免
`uifigure` 环境下整数索引的颜色偏移。

状态更新只传递紧凑标量：连接状态、相机信息、事件量、时间戳、延迟、后端
状态和参数 readback。事件数组、像素矩阵、Base64 或图像历史不经过界面层。

## 停止与关闭

- 点击停止只生成 `stop` 命令；
- `app.run` 关闭 source、清空识别与跟踪状态；
- GUI 保持打开，按钮由“停止运行”变为“开始运行”；
- 点击开始后重新枚举并连接实际序列号；
- 主窗口关闭触发统一 cleanup；
- 参数窗口和分析窗口关闭不会影响相机。
