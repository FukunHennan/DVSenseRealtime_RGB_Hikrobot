%% DVSense DVSLume实时事件跟踪
% 根目录仅保留本文件；界面、相机、算法和存储均在功能目录中。
clearvars; clc;

projectRoot = fileparts(mfilename("fullpath"));
run(fullfile(projectRoot,"tools","dev","setupPath.m"));
runtimeLayout = camera.RuntimeLayout(projectRoot);
runtimePathCleanup = runtimeLayout.addToPath();
cfg = app.loadConfiguration(string(projectRoot));

app.validateEnvironment(cfg);
app.run(cfg);
