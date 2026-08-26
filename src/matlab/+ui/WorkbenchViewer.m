classdef WorkbenchViewer < handle
    properties (SetAccess = private)
        AdapterName string = "workbench"
    end

    properties (Access = private)
        Figure
        LiveHtml
        FramePanel
        FrameSurface
        RgbFramePanel
        RgbFrameSurface
        FusionFramePanel
        FusionFrameSurface
        SettingsFigure
        SettingsHtml
        AnalysisFigure
        AnalysisHtml
        Mailbox
        Parameters struct = struct([])
        Running logical = true
        Recording logical = false
        FigureVisible string = "on"
        DisplayScale double = 1
        DisplayAccumulationUs double = 5000
        LiveState struct
        AnalysisState struct
        CurrentPage string = "live"
        VideoLayout string = "triple"
    end

    methods
        function obj = WorkbenchViewer(cfg)
            obj.Mailbox = ui.internal.CommandMailbox(64);
            obj.LiveState = obj.initialLiveState();
            obj.AnalysisState = obj.initialAnalysisState();
            if ~isfield(cfg,"display") || ~cfg.display.enabled
                obj.Running = false;
                return
            end
            if isfield(cfg.display,"visible") && ~logical(cfg.display.visible)
                obj.FigureVisible = "off";
            end
            if isfield(cfg.display,"scale")
                obj.DisplayScale = max(0.1,min(1,double(cfg.display.scale)));
            end
            if isfield(cfg.display,"accumulationUs")
                obj.DisplayAccumulationUs = max(1000,min(100000, ...
                    round(double(cfg.display.accumulationUs))));
            end
            obj.Running = false;
            obj.LiveState.running = false;
            obj.buildLiveWindow(cfg);
            obj.publishAll();
        end

        function tf = isRunning(obj)
            tf = ~isempty(obj.Figure) && isvalid(obj.Figure);
        end

        function setConnectionStatus(obj,text,state)
            if ~obj.isRunning(), return, end
            stateText = string(state);
            if any(stateText == ["已连接","connected"])
                prefix = "● ";
            elseif any(stateText == ["错误","error"])
                prefix = "● ";
            else
                prefix = "● ";
            end
            obj.LiveState.connection = char(prefix + string(text));
            obj.publishLive();
        end

        function setCameraInfo(obj,info)
            if ~obj.isRunning(), return, end
            obj.LiveState.serial = char(string(localField(info,"serial","--")));
            obj.publishLive();
        end

        function setRgbConnectionStatus(obj,text,state)
            if ~obj.isRunning(), return, end
            obj.LiveState.rgbConnection = char("● "+string(text));
            obj.LiveState.rgbConnectionState = char(string(state));
            obj.publishLive();
        end

        function setRgbCameraInfo(obj,info)
            if ~obj.isRunning(), return, end
            obj.LiveState.rgbSerial = char(string(localField(info,"serial","--")));
            obj.LiveState.rgbModel = char(string(localField(info,"model","--")));
            obj.publishLive();
        end

        function setRgbRunningState(obj,value)
            if ~obj.isRunning(), return, end
            obj.LiveState.rgbRunning = logical(value);
            obj.refreshFrameGeometry();
            obj.publishLive();
        end

        function setRgbExposureState(obj,value)
            if ~obj.isRunning(), return, end
            obj.LiveState.rgbExposureUs = double(value);
            obj.publishLive();
        end

        function updateRgb(obj,frame)
            if ~obj.isRunning() || isempty(frame), return, end
            obj.RgbFrameSurface.update(frame,struct("valid",false));
            drawnow limitrate;
        end

        function setFusionState(obj,status,reason)
            if ~obj.isRunning(), return, end
            obj.LiveState.fusionStatus = char(string(status));
            obj.LiveState.fusionReason = char(string(reason));
            obj.LiveState.fusionReady = string(status) == "ready";
            obj.refreshFrameGeometry();
            obj.publishLive();
        end

        function updateFusion(obj,frame)
            if ~obj.isRunning() || isempty(frame), return, end
            obj.FusionFrameSurface.update(frame,struct("valid",false));
            obj.LiveState.fusionReady = true;
            obj.LiveState.fusionStatus = "ready";
            obj.refreshFrameGeometry();
            obj.publishLive();
            drawnow limitrate;
        end

        function clearFusion(obj)
            if ~obj.isRunning(), return, end
            if ~isempty(obj.FusionFrameSurface)
                try, obj.FusionFrameSurface.reset(); catch, end
            end
            obj.LiveState.fusionReady = false;
            obj.refreshFrameGeometry();
            obj.publishLive();
        end

        function serial = selectRgbCamera(obj,devices,preferredSerial)
            arguments
                obj
                devices struct
                preferredSerial (1,1) string = ""
            end
            if isempty(devices)
                error("Hikrobot:NoCamera","未发现可用的Hikrobot RGB相机。");
            end
            serials = string({devices.serial});
            preferredIndex = find(serials == preferredSerial,1);
            if strlength(preferredSerial) > 0 && ~isempty(preferredIndex)
                serial = serials(preferredIndex);
                return
            end
            if numel(serials) == 1
                serial = serials(1);
                return
            end
            labels = strings(numel(devices),1);
            for index = 1:numel(devices)
                labels(index) = string(devices(index).model)+" | "+serials(index);
            end
            [index,confirmed] = listdlg("PromptString","请选择要连接的Hikrobot RGB相机", ...
                "SelectionMode","single","ListString",cellstr(labels), ...
                "ListSize",[520 190]);
            if ~confirmed || isempty(index)
                error("Hikrobot:CameraSelectionCancelled","用户取消了RGB相机选择。");
            end
            serial = serials(index);
        end

        function serial = selectCamera(obj,devices,preferredSerial)
            arguments
                obj
                devices struct
                preferredSerial (1,1) string = ""
            end
            if isempty(devices)
                error("DVSense:NoCamera","未发现可用的DVSense相机。");
            end
            serials = string({devices.serial});
            preferredIndex = find(serials == preferredSerial,1);
            if strlength(preferredSerial) > 0 && ~isempty(preferredIndex)
                serial = serials(preferredIndex);
                return
            end
            if numel(serials) == 1
                serial = serials(1);
                return
            end
            labels = strings(numel(devices),1);
            for index = 1:numel(devices)
                labels(index) = string(devices(index).product)+" | "+serials(index);
            end
            [index,confirmed] = listdlg("PromptString","请选择要连接的DVSLume相机", ...
                "SelectionMode","single","ListString",cellstr(labels), ...
                "ListSize",[520 190]);
            if ~confirmed || isempty(index)
                error("DVSense:CameraSelectionCancelled","用户取消了相机选择。");
            end
            serial = serials(index);
        end

        function action = resolveConnectionFailure(obj,errorInfo)
            if ~obj.isRunning()
                action = "退出";
                return
            end
            action = string(uiconfirm(obj.Figure, ...
                "连接失败："+string(errorInfo.message)+newline+"请选择下一步。", ...
                "DVSLume连接失败", ...
                "Options",["重新扫描","清理本项目helper","退出"], ...
                "DefaultOption","重新扫描","CancelOption","退出"));
        end

        function update(obj,frame,track,stats)
            if ~obj.isRunning(), return, end
            obj.FrameSurface.update(frame,track);
            obj.LiveState.timestamp = char(formatTimestamp( ...
                localField(stats,"timestampUs",uint64(0))));
            obj.LiveState.eventCount = double(localField(stats,"eventCount",0));
            obj.LiveState.bandwidth = char(localBandwidth( ...
                localField(stats,"eventRate",NaN),obj.LiveState.eventCount));
            if isstruct(stats)
                obj.LiveState.analysisStatus = char(string(localField(stats,"recognitionStatus",obj.LiveState.analysisStatus)));
                obj.LiveState.analysisReason = char(string(localField(stats,"recognitionReason",obj.LiveState.analysisReason)));
                obj.LiveState = obj.mergeLiveDiagnostics(obj.LiveState, ...
                    localField(stats,"recognitionDiagnostics",struct()));
            end
            obj.publishLive();
            drawnow limitrate;
        end

        function setAnalysisResult(obj,riserResult,track,backendState)
            if ~obj.isRunning(), return, end
            obj.FrameSurface.setAnalysis(riserResult);
            obj.AnalysisState = obj.updateAnalysisState(riserResult,track,backendState);
            obj.LiveState.analysisStatus = char(string(obj.AnalysisState.status));
            obj.LiveState.analysisReason = char(string(obj.AnalysisState.reason));
            obj.LiveState.analysisWindowReady = logical(obj.AnalysisState.windowReady);
            obj.LiveState = obj.mergeLiveDiagnostics(obj.LiveState,obj.AnalysisState);
            obj.publishAnalysis();
            obj.publishLive();
        end

        function setRecognitionStatus(obj,status)
            if ~obj.isRunning(), return, end
            obj.AnalysisState = obj.mergeAnalysisStatus(obj.AnalysisState,status);
            obj.LiveState.analysisStatus = char(string(obj.AnalysisState.status));
            obj.LiveState.analysisReason = char(string(obj.AnalysisState.reason));
            obj.LiveState.analysisWindowReady = logical(obj.AnalysisState.windowReady);
            obj.publishAnalysis();
            obj.publishLive();
        end

        function resetProcessingView(obj)
            if ~obj.isRunning(), return, end
            obj.FrameSurface.reset();
            obj.LiveState.timestamp = "--";
            obj.LiveState.eventCount = 0;
            obj.LiveState.bandwidth = "--";
            obj.AnalysisState = obj.initialAnalysisState();
            obj.publishAll();
        end

        function setCommandError(obj,command,message)
            if ~obj.isRunning(), return, end
            type = "命令";
            if isstruct(command) && isfield(command,"type")
                type = string(command.type);
            end
            obj.LiveState.connection = char("● "+type+"失败："+string(message));
            obj.publishLive();
        end

        function pumpEvents(obj)
            if obj.isRunning(), drawnow limitrate, end
        end

        function commands = consumeCommands(obj)
            commands = obj.Mailbox.consume();
        end

        function setRecordingState(obj,value)
            obj.Recording = logical(value);
            obj.LiveState.recording = obj.Recording;
            obj.publishLive();
        end

        function setRunningState(obj,value)
            obj.Running = logical(value);
            obj.LiveState.running = obj.Running;
            obj.publishLive();
        end

        function setDisplayAccumulationUs(obj,value)
            obj.DisplayAccumulationUs = max(1000,min(100000, ...
                round(double(value))));
            obj.publishSettings();
        end

        function setToolParameters(obj,parameters)
            obj.Parameters = parameters;
            obj.publishSettings();
        end

        function setToolParameterState(obj,index,current)
            if index < 1 || index > numel(obj.Parameters), return, end
            obj.Parameters(index).current = current;
            obj.publishSettings();
        end

        function beginROISelection(obj)
            if ~obj.isRunning(), return, end
            obj.FrameSurface.beginROISelection( ...
                @(rectangle)obj.queueROISelection(rectangle), ...
                @()obj.cancelROISelection());
        end

        function showROI(obj,rectangle)
            if ~obj.isRunning(), return, end
            obj.FrameSurface.setROI(rectangle);
        end

        function clearROI(obj)
            if ~obj.isRunning(), return, end
            obj.FrameSurface.clearROI();
        end

        function queueTestEvent(obj,event)
            obj.routeUiEvent(event);
        end

        function handle = getImageHandle(obj)
            handle = obj.FrameSurface.getImageHandle();
        end

        function delete(obj)
            if ~isempty(obj.AnalysisFigure) && isvalid(obj.AnalysisFigure)
                delete(obj.AnalysisFigure);
            end
            if ~isempty(obj.SettingsFigure) && isvalid(obj.SettingsFigure)
                delete(obj.SettingsFigure);
            end
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end

    methods (Access = private)
        function buildLiveWindow(obj,cfg)
            obj.Figure = uifigure("Name","DVSense · DVSLume", ...
                "Visible",obj.FigureVisible,"Position",[40 70 1280 820], ...
                "Color",[10 15 20]/255, ...
                "AutoResizeChildren","off", ...
                "CloseRequestFcn",@(~,~)obj.closeMain(), ...
                "SizeChangedFcn",@(~,~)obj.refreshFrameGeometry());
            obj.LiveHtml = uihtml(obj.Figure,"HTMLSource",obj.asset("workbench.html"), ...
                "DataChangedFcn",@(src,event)obj.receiveHtmlEvent(src,event));
            obj.FramePanel = uipanel(obj.Figure,"BorderType","none", ...
                "BackgroundColor",[112 112 112]/255);
            obj.FrameSurface = ui.internal.FrameSurface(obj.FramePanel, ...
                struct("resolution",cfg.source.resolution,"scale",obj.DisplayScale));
            obj.RgbFramePanel = uipanel(obj.Figure,"BorderType","none", ...
                "BackgroundColor",[10 15 20]/255,"Visible","off");
            obj.RgbFrameSurface = ui.internal.FrameSurface(obj.RgbFramePanel, ...
                struct("resolution",[720 1280],"scale",1));
            obj.FusionFramePanel = uipanel(obj.Figure,"BorderType","none", ...
                "BackgroundColor",[10 15 20]/255,"Visible","off");
            obj.FusionFrameSurface = ui.internal.FrameSurface(obj.FusionFramePanel, ...
                struct("resolution",[720 1280],"scale",1));
            if isfield(cfg,"roi") && isfield(cfg.roi,"enabled") && ...
                    logical(cfg.roi.enabled)
                obj.FrameSurface.setROI(cfg.roi.rectangle);
            end
            obj.refreshFrameGeometry();
        end

        function buildSettingsWindow(obj)
            obj.SettingsFigure = uifigure("Name","DVS设置", ...
                "Visible",obj.FigureVisible,"Position",[1170 70 420 760], ...
                "Color",[1 1 1], ...
                "CloseRequestFcn",@(~,~)obj.hideSettings());
            layout = uigridlayout(obj.SettingsFigure,[1 1]);
            layout.Padding = [0 0 0 0];
            obj.SettingsHtml = uihtml(layout, ...
                "HTMLSource",obj.asset("settings.html"), ...
                "DataChangedFcn",@(src,event)obj.receiveHtmlEvent(src,event));
        end

        function buildAnalysisWindow(obj)
            obj.AnalysisFigure = uifigure("Name","轮廓与中心线分析", ...
                "Visible","off","Position",[60 80 720 600], ...
                "Color",[1 1 1], ...
                "CloseRequestFcn",@(~,~)obj.hideAnalysis());
            layout = uigridlayout(obj.AnalysisFigure,[1 1]);
            layout.Padding = [0 0 0 0];
            obj.AnalysisHtml = uihtml(layout, ...
                "HTMLSource",obj.asset("analysis.html"));
        end

        function refreshFrameGeometry(obj)
            if isempty(obj.Figure) || ~isvalid(obj.Figure) || ...
                    isempty(obj.FramePanel) || ~isvalid(obj.FramePanel)
                return
            end
            width = obj.Figure.Position(3);
            height = obj.Figure.Position(4);
            obj.LiveHtml.Position = [1 1 width height];

            if obj.CurrentPage ~= "live" || obj.VideoLayout == "single"
                obj.FramePanel.Visible = "off";
                if ~isempty(obj.RgbFramePanel) && isvalid(obj.RgbFramePanel)
                    obj.RgbFramePanel.Visible = "off";
                end
                if ~isempty(obj.FusionFramePanel) && isvalid(obj.FusionFramePanel)
                    obj.FusionFramePanel.Visible = "off";
                end
                return
            end

            stageLeft = 76;
            pagePadding = 14;
            sideWidth = 330;
            gap = 12;
            headerHeight = 47;
            footerHeight = 36;
            topbarHeight = 58;
            x = stageLeft + pagePadding;
            shellBottom = footerHeight + pagePadding;
            shellTop = height - topbarHeight - pagePadding - headerHeight;
            shellHeight = max(220,shellTop-shellBottom);
            mainWidth = max(420,width-stageLeft-2*pagePadding-gap-sideWidth);

            if obj.VideoLayout == "dual"
                panelY = shellBottom;
                panelWidth = max(200,(mainWidth-1)/2);
                panelHeight = shellHeight;
                fusionHeight = 0;
            else
                topFraction = 1/(1+0.78);
                topHeight = max(180,(shellHeight-1)*topFraction);
                lowerHeight = shellHeight-1-topHeight;
                panelY = shellBottom + lowerHeight + 1;
                panelWidth = max(200,(mainWidth-1)/2);
                panelHeight = topHeight;
                fusionHeight = lowerHeight;
            end
            obj.FramePanel.Position = [x panelY panelWidth panelHeight];
            obj.FramePanel.Visible = "on";
            if ~isempty(obj.RgbFramePanel) && isvalid(obj.RgbFramePanel)
                obj.RgbFramePanel.Position = [x+panelWidth+1 panelY panelWidth panelHeight];
                if logical(localField(obj.LiveState,"rgbRunning",false))
                    obj.RgbFramePanel.Visible = "on";
                else
                    obj.RgbFramePanel.Visible = "off";
                end
            end
            if ~isempty(obj.FusionFramePanel) && isvalid(obj.FusionFramePanel)
                if obj.VideoLayout == "triple" && fusionHeight > 0
                    obj.FusionFramePanel.Position = [x shellBottom mainWidth fusionHeight];
                    if logical(localField(obj.LiveState,"fusionReady",false))
                        obj.FusionFramePanel.Visible = "on";
                    else
                        obj.FusionFramePanel.Visible = "off";
                    end
                else
                    obj.FusionFramePanel.Visible = "off";
                end
            end
        end

        function receiveHtmlEvent(obj,source,event)
            payload = [];
            if nargin >= 3 && isprop(event,"Data")
                payload = event.Data;
            elseif ~isempty(source) && isprop(source,"Data")
                payload = source.Data;
            end
            if isempty(payload) || ~isstruct(payload) || ~isfield(payload,"type")
                return
            end
            try
                obj.routeUiEvent(payload);
            catch err
                obj.setCommandError(payload,err.message);
            end
        end

        function routeUiEvent(obj,event)
            type = string(event.type);
            switch type
                case "pageChanged"
                    if isfield(event,"payload") && isstruct(event.payload) && isfield(event.payload,"page")
                        obj.CurrentPage = string(event.payload.page);
                        obj.refreshFrameGeometry();
                    end
                    return
                case "videoLayoutChanged"
                    if isfield(event,"payload") && isstruct(event.payload) && isfield(event.payload,"layout")
                        obj.VideoLayout = string(event.payload.layout);
                        obj.refreshFrameGeometry();
                    end
                    return
                case "showSettings"
                    obj.showSettings();
                case "showAnalysis"
                    obj.showAnalysis();
                case "beginROISelection"
                    obj.beginROISelection();
                case "clearROI"
                    obj.clearROI();
                    obj.Mailbox.push(ui.internal.mapControlEvent(event,obj.Parameters));
                case "snapshot"
                    return
                otherwise
                    command = ui.internal.mapControlEvent(event,obj.Parameters);
                    obj.Mailbox.push(command);
            end
        end

        function showSettings(obj)
            if ~isempty(obj.SettingsFigure) && isvalid(obj.SettingsFigure)
                obj.SettingsFigure.Visible = "on";
                figure(obj.SettingsFigure);
            end
        end

        function hideSettings(obj)
            if ~isempty(obj.SettingsFigure) && isvalid(obj.SettingsFigure)
                obj.SettingsFigure.Visible = "off";
            end
        end

        function showAnalysis(obj)
            if ~isempty(obj.AnalysisFigure) && isvalid(obj.AnalysisFigure)
                obj.AnalysisFigure.Visible = "on";
                figure(obj.AnalysisFigure);
            end
        end

        function hideAnalysis(obj)
            if ~isempty(obj.AnalysisFigure) && isvalid(obj.AnalysisFigure)
                obj.AnalysisFigure.Visible = "off";
            end
        end

        function publishAll(obj)
            obj.publishLive();
            obj.publishSettings();
            obj.publishAnalysis();
        end

        function publishLive(obj)
            if ~isempty(obj.LiveHtml) && isvalid(obj.LiveHtml)
                obj.LiveHtml.Data = obj.LiveState;
            end
        end

        function publishSettings(obj)
            if isempty(obj.SettingsHtml) || ~isvalid(obj.SettingsHtml), return, end
            parameters = obj.presentationParameters();
            obj.SettingsHtml.Data = struct("parameters",parameters, ...
                "parameterJson",jsonencode(parameters), ...
                "displayAccumulationUs",obj.DisplayAccumulationUs);
        end

        function publishAnalysis(obj)
            if ~isempty(obj.AnalysisHtml) && isvalid(obj.AnalysisHtml)
                obj.AnalysisHtml.Data = obj.AnalysisState;
            end
        end

        function queueROISelection(obj,rectangle)
            obj.showROI(rectangle);
            obj.Mailbox.push(struct("type","setROI","rectangle",rectangle));
        end

        function cancelROISelection(~)
        end

        function values = presentationParameters(obj)
            count = numel(obj.Parameters);
            values = repmat(struct("tool","","name","","type","", ...
                "current","","min",0,"max",1,"options",strings(0)),1,count);
            for index = 1:count
                parameter = obj.Parameters(index);
                values(index).tool = char(string(parameter.tool));
                values(index).name = char(string(parameter.name));
                values(index).type = char(upper(string(parameter.type)));
                values(index).current = localScalarValue(parameter.current);
                values(index).min = localNumber(parameter,"min",0);
                values(index).max = localNumber(parameter,"max",1);
                if isfield(parameter,"options")
                    values(index).options = string(parameter.options);
                end
            end
        end

        function path = asset(~,name)
            path = fullfile(fileparts(mfilename("fullpath")),"assets",name);
        end

        function closeMain(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end

        function state = initialLiveState(~)
            state = struct("serial","--","timestamp","--", ...
                "connection","● 等待连接","eventCount",0, ...
                "bandwidth","--","running",false,"recording",false, ...
                "analysisStatus","--","analysisReason","--", ...
                "analysisWindowReady",false, ...
                "rawEventCount",0,"filteredEventCount",0, ...
                "maskPixelCount",0,"outlinePointCount",0, ...
                "centerlinePointCount",0, ...
                "rgbRunning",false,"rgbSerial","--","rgbModel","--", ...
                "rgbConnection","● 未连接","rgbConnectionState","未连接", ...
                "rgbExposureUs",NaN, ...
                "fusionReady",false,"fusionStatus","waiting-dvs", ...
                "fusionReason","等待 DVS 与 RGB 最新显示帧。");
        end

        function state = initialAnalysisState(~)
            state = struct("pointCount",0,"length","--", ...
                "motion","--","backend","cpu","centerline",zeros(0,2), ...
                "status","--","reason","--","rawEventCount",0, ...
                "filteredEventCount",0,"maskPixelCount",0, ...
                "outlinePointCount",0,"centerlinePointCount",0, ...
                "windowReady",false,"confidence",0);
        end

        function state = updateAnalysisState(obj,riserResult,track,backendState)
            state = obj.initialAnalysisState();
            state = obj.mergeAnalysisResult(state,riserResult);
            state = obj.mergeAnalysisStatus(state,riserResult);
            if isstruct(track) && isfield(track,"valid") && track.valid
                state.motion = "跟踪中";
            end
            if nargin >= 4 && isstruct(backendState)
                executed = string(localField(backendState,"executed","cpu"));
                state.backend = char(executed);
            end
        end

        function state = mergeAnalysisResult(~,state,riserResult)
            if ~isstruct(riserResult), return, end
            if isfield(riserResult,"outline")
                state.pointCount = size(riserResult.outline,1);
                state.outlinePointCount = size(riserResult.outline,1);
            end
            if isfield(riserResult,"centerline")
                centerline = double(riserResult.centerline);
                state.centerline = centerline;
                state.length = char(localCenterlineLength(centerline));
                state.centerlinePointCount = size(centerline,1);
            end
            if isfield(riserResult,"state")
                state.motion = char(string(riserResult.state));
            end
            if isfield(riserResult,"confidence")
                state.confidence = double(riserResult.confidence);
            end
        end

        function state = mergeAnalysisStatus(~,state,status)
            if ~isstruct(status), return, end
            state.status = char(string(localField(status,"status",state.status)));
            state.reason = char(string(localField(status,"reason",state.reason)));
            state.rawEventCount = double(localField(status,"rawEventCount",state.rawEventCount));
            state.filteredEventCount = double(localField(status,"filteredEventCount",state.filteredEventCount));
            state.maskPixelCount = double(localField(status,"maskPixelCount",state.maskPixelCount));
            state.outlinePointCount = double(localField(status,"outlinePointCount",state.outlinePointCount));
            state.centerlinePointCount = double(localField(status,"centerlinePointCount",state.centerlinePointCount));
            state.windowReady = logical(localField(status,"windowReady",state.windowReady));
            if isfield(status,"confidence")
                state.confidence = double(status.confidence);
            end
        end

        function state = mergeLiveDiagnostics(~,state,diagnostics)
            if ~isstruct(diagnostics), return, end
            fields = ["rawEventCount","filteredEventCount","maskPixelCount", ...
                "outlinePointCount","centerlinePointCount"];
            for index = 1:numel(fields)
                field = fields(index);
                state.(field) = double(localField(diagnostics,field,state.(field)));
            end
        end
    end
end

function value = localField(valueStruct,field,defaultValue)
if isstruct(valueStruct) && isfield(valueStruct,field)
    value = valueStruct.(field);
else
    value = defaultValue;
end
end

function text = formatTimestamp(value)
value = uint64(value);
seconds = floor(double(value)/1e6);
microseconds = mod(double(value),1e6);
text = string(sprintf("%02d:%02d:%02d:%06d", ...
    floor(seconds/3600),mod(floor(seconds/60),60),mod(seconds,60),microseconds));
end

function text = localBandwidth(eventRate,eventCount)
if isfinite(double(eventRate)) && double(eventRate) >= 0
    text = string(sprintf("%.1f Mev/s",double(eventRate)/1e6));
else
    text = string(sprintf("%.1f Mev/s",double(eventCount)/1e6));
end
end

function text = localCenterlineLength(centerline)
if size(centerline,1) < 2
    text = "--";
    return
end
distance = sum(sqrt(sum(diff(centerline,1,1).^2,2)));
text = string(sprintf("%.0f px",distance));
end

function value = localScalarValue(raw)
if islogical(raw) || isnumeric(raw)
    value = raw;
else
    value = char(string(raw));
end
end

function value = localNumber(parameter,field,defaultValue)
value = defaultValue;
if ~isfield(parameter,field) || isempty(parameter.(field)), return, end
candidate = str2double(string(parameter.(field)));
if isfinite(candidate), value = candidate; end
end
