function captureOfficialWorkbenchFinal
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
run(fullfile(projectRoot,"tools","dev","setupPath.m"));

cfg.display.enabled = true;
cfg.display.visible = true;
cfg.display.scale = 0.75;
cfg.display.refreshHz = 25;
cfg.source.resolution = [720 1280];
cfg.roi.enabled = false;
cfg.roi.rectangle = [1 1 1280 720];

viewer = ui.WorkbenchViewer(cfg);
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>

parameterFile = fullfile(projectRoot,"config","dvsense_default_parameters.json");
if isfile(parameterFile)
    defaults = jsondecode(fileread(parameterFile));
    parameters = localParameters(defaults);
    viewer.setToolParameters(parameters);
end

frame = ones(540,960,"uint8");
frame(180:420,360:600) = 2;
frame(220:400,470:520) = 3;
track = struct("valid",true,"boundingBox",[360 180 240 240], ...
    "position",[480;300]);
stats = struct("timestampUs",uint64(12603147),"eventCount",937412, ...
    "latencyUs",742,"backend","CPU fallback");
viewer.setCameraInfo(struct("product","DVSLume","serial","ffffffffffffffaf"));
viewer.setConnectionStatus("已连接，正在实时取流","已连接");
viewer.update(frame,track,stats);
viewer.setAnalysisResult(struct( ...
    "valid",true, ...
    "outline",[360 180; 420 182; 500 220; 560 300; 500 390; 410 420; 350 360; 340 260; 360 180], ...
    "centerline",[400 200; 440 250; 470 310; 455 370], ...
    "curvature",[0.1;0.2;0.15;0.08], ...
    "confidence",0.92, ...
    "state","stable"), ...
    struct("valid",true,"boundingBox",[360 180 240 240], ...
    "position",[480;300]), ...
    struct("requested","matlab-gpu","executed","cpu", ...
    "fallback",true,"reason","preview"));

pause(0.5);
figures = findall(groot,"Type","figure");
figures = figures(isgraphics(figures));
names = string(get(figures,"Name"));
outputRoot = fullfile(projectRoot,"artifacts","previews","ui-previews","final");
if ~isfolder(outputRoot), mkdir(outputRoot); end
for index = 1:numel(figures)
    if contains(names(index),"DVSense · DVSLume")
        exportapp(figures(index),fullfile(outputRoot, ...
            "dvsense-official-workbench-v2.png"));
    elseif contains(names(index),"DVS设置")
        figures(index).Visible = "on";
        exportapp(figures(index),fullfile(outputRoot, ...
            "dvsense-official-settings-v2.png"));
    elseif contains(names(index),"轮廓与中心线")
        figures(index).Visible = "on";
        exportapp(figures(index),fullfile(outputRoot, ...
            "dvsense-official-analysis-v2.png"));
    end
end
end

function parameters = localParameters(values)
tools = ["Biases","AntiFlicker","EventRateControl","EventTrailFilter","ROI","Sync","TriggerIn"];
parameters = struct("tool",{},"name",{},"type",{},"current",{}, ...
    "min",{},"max",{},"unit",{},"options",{});
for tool = tools
    if ~isfield(values,tool), continue, end
    names = fieldnames(values.(tool));
    for index = 1:numel(names)
        name = names{index};
        current = values.(tool).(name);
        if islogical(current)
            type = "BOOL"; minimum = []; maximum = []; options = strings(0);
        elseif isnumeric(current)
            type = "INT"; minimum = -100; maximum = 100; options = strings(0);
        else
            type = "ENUM"; minimum = []; maximum = [];
            options = string(current);
        end
        parameters(end+1) = struct("tool",char(tool),"name",name, ...
            "type",char(type),"current",current,"min",minimum, ...
            "max",maximum,"unit","","options",options); %#ok<AGROW>
    end
end
end
