# GPU识别加速路线

> 当前状态：GPU后端选择与回退检测已经存在，但
> `analysis.GpuRiserAnalysisBackend`仍委托CPU实现完成立管识别。本文件描述后续
> 加速路线，不代表GPU识别算法已经投入生产。

## 目标与边界

GPU用于事件识别，不参与GUI绘制。当前显示帧已经由
`dvsense_helper.exe`在SDK事件回调中写入固定大小双缓冲，MATLAB只读取最新
`uint8`帧；把这条显示链路搬到GPU会增加上传、同步和`gather`开销。

识别后端继续使用`analysis.MeasurementBackend`作为seam。CPU、MATLAB GPU和未来CUDA
MEX adapter都接收事件窗口，并输出相同measurement结构：

- `valid`
- `position`
- `boundingBox`
- `confidence`

跟踪器、录制器和GUI不依赖具体GPU实现。

## 推荐实现顺序

1. 保留当前`MatlabGpuMeasurementBackend`作为算法正确性与工具链验证后端。
2. 增加`CudaMexBackend` adapter，先实现活动滤波、网格统计和质心/边界框。
3. 使用固定容量SoA输入：`x`、`y`、`polarity`、`timestamp`分别存储。
4. 预分配页锁定host缓冲、device缓冲和输出缓冲，运行期不反复分配。
5. 使用独立CUDA stream异步上传和计算，只在读取小型measurement结果时同步。
6. 后续在同一adapter内增加time surface、event voxel、聚类和模型推理。

## 调度原则

- 采集线程只负责把最新事件写入有界缓冲。
- GPU工作线程消费固定容量识别窗口，落后时丢弃旧窗口而不是无限排队。
- GUI只读取最新帧和最新识别结果，不能等待GPU完成。
- CPU和CUDA必须使用相同ROI坐标约定和measurement输出。
- 只有在端到端P95/P99延迟和内存占用优于CPU时才自动选择CUDA。

## 验证指标

- CPU与CUDA输出位置、边界框和置信度的一致性。
- 事件数从稀疏到高负载时的吞吐、P50、P95、P99和最大延迟。
- 连续30分钟运行时host/device内存是否保持稳定。
- GPU超时、设备丢失或模型加载失败时能否回退CPU。
- 停止运行时CUDA stream、MEX和helper是否按顺序释放。

## 后续模型

目标识别可分两级：

- 高频事件前端：活动滤波、时空表征、聚类和短周期跟踪。
- 低频语义后端：ONNX/TensorRT模型提供类别和检测框校正。

语义模型不应阻塞高频事件跟踪；当模型结果较慢时，系统继续使用最近一次检测框和
卡尔曼状态。
