# Hikrobot RGB 实机冒烟记录（2026-08-25）

## 环境

- 相机：Hikrobot MV-CU050-90UC
- 序列号：DA7653943
- 设备版本：V4.0.1 220914 887585
- MATLAB：R2024b
- 原生编译器：Visual Studio Community 2026，MSVC x64
- MATLAB MEX 编译器：Visual Studio 2022 Build Tools 17.14
- MVS SDK：`C:/Program Files (x86)/MVS`
- MVS Runtime：`C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64`

## 测试范围

使用 `tests/native/hik_connection_smoke.cpp` 验证：

1. 初始化 MVS SDK；
2. 枚举并打开真实 USB3 相机；
3. 读取曝光，写回同一曝光值并再次读回；
4. 关闭触发模式并连续采集 5 秒；
5. 检查非空帧和帧号间隙；
6. 停止、关闭、销毁句柄并释放 SDK。

曝光测试使用同值写回，不主动改变测试前的曝光设置。

## 结果

```text
device_count=1
model=MV-CU050-90UC
serial=DA7653943
get_exposure_result=0x0 exposure_us=5000
set_exposure_result=0x0
exposure_readback_result=0x0 exposure_us=5000
first_size=2600x2160
frames=299
nonempty_frames=299
frame_gap_count=0
stop_result=0x0
close_result=0x0
destroy_result=0x0
finalize_result=0x0
result=PASS
```

## MATLAB MEX 与应用适配器结果

初次构建时，MATLAB R2024b 未识别 Visual Studio 2026。并行安装 Visual
Studio 2022 Build Tools 后，`mex -setup C++` 成功选择 Microsoft Visual C++
2022，`tools/build/buildHikrobotMex.m` 随后成功生成：

```text
runtime/bin/hikrobot_mex.mexw64
```

通过 `camera.HikrobotCameraSource` 的 MATLAB 实机验证覆盖：

- 枚举 1 台真实相机并取得正确型号和序列号；
- 打开设备并应用 JSON 配置中的 2800 µs 曝光；
- 曝光同值写回成功；
- 取得 720×1280×3 `uint8` RGB 预览帧；
- 正常关闭设备。

刚开始采集时，单次 5 ms MEX 读取可能在首帧到达前返回空数组。应用的
25 Hz 显示循环会自然重试；正式验证使用最长 5 秒的有界重试确认帧到达。
