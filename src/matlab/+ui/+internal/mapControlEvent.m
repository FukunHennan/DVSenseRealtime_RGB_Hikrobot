function command = mapControlEvent(event, parameters)
arguments
    event (1,1) struct
    parameters struct
end

if ~isfield(event,"version") || double(event.version) ~= 1
    error("DVSense:UIProtocolVersion","不支持的界面命令协议版本。");
end
if ~isfield(event,"type")
    error("DVSense:InvalidUiEvent","界面事件缺少type字段。");
end

type = string(event.type);
payload = struct;
if isfield(event,"payload") && isstruct(event.payload)
    payload = event.payload;
end

switch type
    case {"start","stop","startRecording","stopRecording","showAnalysis", ...
            "hideAnalysis","setOverlayVisible","beginROISelection","clearROI", ...
            "connectRgb","disconnectRgb"}
        command = struct("type",char(type));
        if type == "setOverlayVisible"
            requireField(payload,"value");
            command.value = logical(payload.value);
        end
    case "setRgbExposureUs"
        requireField(payload,"value");
        value = double(payload.value);
        if ~isscalar(value) || ~isfinite(value) || value < 20 || value > 1000000
            error("Hikrobot:Exposure","RGB曝光时间必须在20到1000000微秒之间。");
        end
        command = struct("type","setRgbExposureUs","value",value);
    case "setDisplayAccumulationUs"
        requireField(payload,"value");
        value = double(payload.value);
        if ~isscalar(value) || ~isfinite(value) || value < 1000 || value > 100000
            error("DVSense:InvalidDisplayAccumulation", ...
                "事件累计时间必须在1到100 ms之间。");
        end
        command = struct("type","setDisplayAccumulationUs", ...
            "value",round(value));
    case "setROI"
        requireField(payload,"rectangle");
        rectangle = double(payload.rectangle);
        if ~isequal(size(rectangle),[1 4]) || any(~isfinite(rectangle)) || ...
                any(rectangle(3:4) <= 0)
            error("DVSense:InvalidROI","ROI必须是有效的[x y width height]。");
        end
        command = struct("type","setROI","rectangle",rectangle);
    case "setToolParameter"
        for field = ["index","tool","name","value"]
            requireField(payload,field);
        end
        index = double(payload.index);
        if ~isscalar(index) || index < 1 || index ~= fix(index) || ...
                index > numel(parameters)
            error("DVSense:ParameterNotFound","界面参数索引无效。");
        end
        parameter = parameters(index);
        if string(parameter.tool) ~= string(payload.tool) || ...
                string(parameter.name) ~= string(payload.name)
            error("DVSense:ParameterNotFound","界面参数与SDK元数据不匹配。");
        end
        value = camera.validateToolParameter(parameter,payload.value);
        command = struct("type","setToolParameter","index",index, ...
            "tool",char(string(parameter.tool)),"name", ...
            char(string(parameter.name)),"value",value);
    otherwise
        error("DVSense:UnsupportedUiEvent","不支持的界面事件：%s",type);
end

if isfield(event,"sequence")
    command.sequence = event.sequence;
end
end

function requireField(value, field)
if ~isfield(value,field)
    error("DVSense:InvalidUiEvent","界面事件缺少字段：%s。",field);
end
end
