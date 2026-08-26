classdef DVSenseCameraSource < camera.CameraSource
    properties (Access=private)
        Config struct
        Opened logical = false
        Resolution double = [NaN NaN]
        Info struct = struct()
        Session
        SelectedSerial string = ""
        SessionFactory = []
    end
    methods
        function obj = DVSenseCameraSource(cfg,sessionFactory)
            arguments
                cfg struct
                sessionFactory = []
            end
            obj.Config = cfg;
            obj.SessionFactory = sessionFactory;
        end
        function devices=discover(obj)
            obj.ensureSession();
            devices=obj.Session.discover();
        end
        function open(obj,selectedSerial)
            arguments
                obj
                selectedSerial (1,1) string = ""
            end
            obj.ensureSession();
            if strlength(selectedSerial)==0
                devices=obj.discover();
                selectedSerial=camera.selectCameraSerial( ...
                    devices,string(obj.Config.camera.serial));
            end
            obj.SelectedSerial=selectedSerial;
            fprintf("正在连接DVSLume（序列号：%s）……\n",selectedSerial);
            obj.Session.open(selectedSerial);
            obj.Opened = true;
            obj.Info=obj.Session.getInfo();
            obj.Info.toolParameters=obj.Session.getToolParameters();
            obj.applyDefaultToolParameters();
            obj.Resolution = [obj.Info.height obj.Info.width];
            obj.Session.setBatchTime(double(obj.Config.source.windowUs));
            obj.Session.setDisplayWindow(obj.displayAccumulationUs());
            if obj.roiMode() == "hardware"
                if obj.Config.roi.enabled
                    obj.Session.setROI(obj.Config.roi.rectangle);
                else
                    obj.Session.setROI(obj.fullFrameROI());
                end
            end
            obj.Session.start();
            fprintf("相机已打开，正在等待事件流……\n");
            for k=1:obj.Config.camera.connection.warmupBatches
                obj.Session.readEvents();
            end
            fprintf("DVSLume已就绪。\n");
        end
        function tf = hasData(obj), tf = obj.Opened; end
        function packet = read(obj)
            packet = obj.Session.readEvents();
            packet.resolution = obj.Resolution;
            if isempty(packet.timestamp)
                packet.timeStartUs = uint64(0);
                packet.timeEndUs = uint64(0);
            else
                packet.timeStartUs = min(packet.timestamp);
                packet.timeEndUs = max(packet.timestamp);
            end
            packet.roiOffset = [0 0];
        end
        function frame=readDisplayFrame(obj)
            assert(obj.Opened,"相机尚未连接。");
            frame=obj.Session.readDisplayFrame();
        end
        function close(obj)
            if ~isempty(obj.Session)
                try, obj.Session.close(); catch, end
            end
            obj.Opened=false;
        end
        function delete(obj)
            try, obj.close(); catch, end
        end
        function info=getInfo(obj), info=obj.Info; end
        function parameters=getToolParameters(obj)
            parameters=obj.Info.toolParameters;
        end
        function current=setToolParameter(obj,toolName,parameterName,value)
            assert(obj.Opened,"相机尚未连接。");
            parameters=obj.getToolParameters();
            matches=strcmp(string({parameters.tool}),string(toolName)) & ...
                strcmp(string({parameters.name}),string(parameterName));
            if nnz(matches)~=1
                error("DVSense:ParameterNotFound", ...
                    "未找到SDK参数：%s/%s",toolName,parameterName);
            end
            parameter=parameters(matches);
            typedValue=camera.validateToolParameter(parameter,value);
            type=upper(string(parameter.type));
            switch type
                case "BOOL"
                    valueText=string(typedValue);
                    if typedValue, valueText="true"; else, valueText="false"; end
                otherwise
                    valueText=string(typedValue);
            end
            current=obj.Session.setParameter(toolName,parameterName,typedValue);
            obj.Info.toolParameters=camera.applyToolParameterReadback( ...
                obj.Info.toolParameters,string(toolName), ...
                string(parameterName),current);
        end
        function setROI(obj,rectangle)
            rectangle = double(rectangle);
            if ~isequal(size(rectangle),[1 4]) || any(~isfinite(rectangle)) || ...
                    any(rectangle(3:4) <= 0)
                error("DVSense:InvalidROI","ROI必须是有效的[x y width height]。");
            end
            obj.Config.roi.enabled = true;
            obj.Config.roi.rectangle = rectangle;
            if obj.Opened && obj.roiMode() == "hardware"
                obj.Session.setROI(rectangle);
            end
        end
        function clearROI(obj)
            obj.Config.roi.enabled = false;
            obj.Config.roi.rectangle = obj.fullFrameROI();
            if obj.Opened && obj.roiMode() == "hardware"
                obj.Session.setROI(obj.Config.roi.rectangle);
            end
        end
        function setBatchTime(obj,windowUs)
            value=max(1,round(double(windowUs)));
            obj.Config.source.windowUs=uint64(value);
            if obj.Opened
                obj.Session.setBatchTime(uint64(value));
            end
        end
        function setDisplayAccumulation(obj,windowUs)
            value=max(1000,min(100000,round(double(windowUs))));
            obj.Config.display.accumulationUs=uint64(value);
            if obj.Opened
                obj.Session.setDisplayWindow(uint64(value));
            end
        end
        function resetDisplayAccumulation(obj)
            if obj.Opened
                obj.Session.setDisplayWindow(obj.displayAccumulationUs());
            end
        end
        function startRawRecording(obj,path)
            assert(obj.Opened,"相机尚未连接。");
            if ~isfolder(path), mkdir(path); end
            stamp=string(datetime("now","Format","yyyyMMdd_HHmmss"));
            file=fullfile(path,"events_"+stamp+".raw");
            obj.Session.startRecording(file);
        end
        function stopRawRecording(obj)
            if obj.Opened, obj.Session.stopRecording(); end
        end
        function helpers=listStaleHelpers(obj)
            obj.ensureSession();
            helpers=obj.Session.listStaleHelpers();
        end
        function terminateStaleHelpers(obj)
            obj.ensureSession();
            obj.Session.terminateStaleHelpers();
        end
    end
    methods (Access=private)
        function mode = roiMode(obj)
            mode = "software";
            if isfield(obj.Config,"roi") && isfield(obj.Config.roi,"mode")
                mode = lower(string(obj.Config.roi.mode));
            end
        end
        function rectangle = fullFrameROI(obj)
            resolution = double(obj.Config.source.resolution);
            if all(isfinite(obj.Resolution)) && all(obj.Resolution > 0)
                resolution = obj.Resolution;
            end
            rectangle = [1 1 round(resolution(2)) round(resolution(1))];
        end
        function ensureSession(obj)
            if isempty(obj.Session)
                if ~isempty(obj.SessionFactory)
                    obj.Session = obj.SessionFactory( ...
                        obj.Config.paths.runtimeRoot, ...
                        obj.Config.source.live.batchEvents);
                else
                    obj.Session=camera.DVSenseSession( ...
                        obj.Config.paths.runtimeRoot, ...
                        obj.Config.source.live.batchEvents);
                end
            end
        end
        function applyDefaultToolParameters(obj)
            defaultFile = "";
            if isfield(obj.Config,"paths") && ...
                    isfield(obj.Config.paths,"defaultParameterFile")
                defaultFile = string(obj.Config.paths.defaultParameterFile);
            end
            if strlength(defaultFile) == 0 || ~isfile(defaultFile)
                return
            end
            defaults = jsondecode(fileread(defaultFile));
            toolNames = string(fieldnames(defaults));
            for toolIndex = 1:numel(toolNames)
                toolName = toolNames(toolIndex);
                parameterNames = string(fieldnames(defaults.(toolName)));
                for parameterIndex = 1:numel(parameterNames)
                    parameterName = parameterNames(parameterIndex);
                    if ~obj.hasToolParameter(toolName,parameterName)
                        continue
                    end
                    obj.setToolParameter(toolName,parameterName, ...
                        defaults.(toolName).(parameterName));
                end
            end
        end
        function tf = hasToolParameter(obj,toolName,parameterName)
            tf = false;
            if ~isfield(obj.Info,"toolParameters") || isempty(obj.Info.toolParameters)
                return
            end
            tf = nnz(strcmp(string({obj.Info.toolParameters.tool}),string(toolName)) & ...
                strcmp(string({obj.Info.toolParameters.name}),string(parameterName))) == 1;
        end
        function value=displayAccumulationUs(obj)
            value=uint64(5000);
            if isfield(obj.Config,"display") && ...
                    isfield(obj.Config.display,"accumulationUs")
                value=uint64(max(1000,min(100000, ...
                    round(double(obj.Config.display.accumulationUs)))));
            end
        end
    end
end
