# V4 Production Cleanup

## 根目录整理

根目录保留：`main.m`、`README.md`、`VERSION`、`.gitignore` 与必要目录。

- 启动 BAT -> `tools/launcher/`
- GUI 整合说明 -> `docs/integration/`
- 删除旧 `archive/`

## 去除非真实功能

产品 UI 不再提供任何 Mock / Simulator / 文件回放入口。

仅真实后端已接入的能力可点击：

- DVS 真实连接/断开
- DVS FrameSurface 实时预览
- ROI
- DVS 原始事件录制
- 现有真实 DVS 分析链路

后端尚未接入的能力统一禁用：

- Hikrobot RGB 连接
- RGB 去畸变文件
- Fusion / 双相机标定
- RGB 曝光
- DVS 融合阈值接口
- 画面拖动对齐与标定保存
- RGB/Fusion 视频录制
- 分析 CSV 导出
- 设置持久化

原则：有真实后端才启用，没有则显示不可用。
