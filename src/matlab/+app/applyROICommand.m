function cfg = applyROICommand(cfg,command)
arguments
    cfg (1,1) struct
    command (1,1) struct
end

if ~isfield(cfg,"source") || ~isfield(cfg.source,"resolution")
    error("DVSense:InvalidROIConfig","ROI需要有效的相机分辨率。");
end
if ~isfield(cfg,"roi")
    cfg.roi = struct;
end

resolution = double(cfg.source.resolution);
if ~isequal(size(resolution),[1 2]) || any(~isfinite(resolution)) || ...
        any(resolution <= 0)
    error("DVSense:InvalidROIConfig","ROI需要有效的相机分辨率。");
end
if ~isfield(command,"type")
    error("DVSense:InvalidROI","ROI命令缺少类型。");
end

switch string(command.type)
    case "setROI"
        if ~isfield(command,"rectangle")
            error("DVSense:InvalidROI","设置ROI缺少矩形坐标。");
        end
        cfg.roi.enabled = true;
        cfg.roi.rectangle = ui.internal.normalizeROI( ...
            double(command.rectangle),resolution);
    case "clearROI"
        cfg.roi.enabled = false;
        cfg.roi.rectangle = [1 1 round(resolution(2)) round(resolution(1))];
    otherwise
        error("DVSense:InvalidROI","不支持的ROI命令：%s",string(command.type));
end
end
