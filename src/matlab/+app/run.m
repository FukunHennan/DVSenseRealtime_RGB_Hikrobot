function run(cfg)
arguments
    cfg struct
end

src = camera.CameraSourceFactory.create(cfg);
rgbSrc = [];
backend = analysis.MeasurementBackendFactory.create(cfg);
riserBackend = analysis.RiserBackendFactory.create(cfg);
tracker = analysis.MotionTracker(cfg.tracking);
recognitionFilter = analysis.ActivityFilter;
recorder = analysis.SessionRecorder(cfg);
viewer = ui.LiveViewer(cfg);
recognitionAccumulator = analysis.RecognitionWindow( ...
    cfg.processing.recognitionWindowUs,cfg.processing.recognitionMaxEvents, ...
    localRecognitionMinEvents());
batchTimeUs = double(cfg.source.windowUs);
displayAccumulationUs = 5000;
if isfield(cfg,"display") && isfield(cfg.display,"accumulationUs")
    displayAccumulationUs = max(1000,min(100000, ...
        round(double(cfg.display.accumulationUs))));
end

cleanup = onCleanup(@shutdown); %#ok<NASGU>
% GUI-first startup: the application remains usable with no camera attached.
% A real DVSLume connection is created only after the user presses Start/Connect.
selectedSerial = "";
viewer.setConnectionStatus("未连接相机，可在设备页扫描并连接","未连接");
viewer.setRunningState(false);
viewer.setRgbRunningState(false);
viewer.setRgbConnectionStatus("RGB未连接，可在设备页连接Hikrobot","未连接");
viewer.setDisplayAccumulationUs(displayAccumulationUs);
recorder.open();

startTime = tic;
lastDisplay = tic;
lastRgbDisplay = tic;
running = false;
rgbRunning = false;
sequence = uint64(0);
track = struct("valid",false,"timestampUs",uint64(0), ...
    "position",[NaN;NaN],"velocity",[NaN;NaN], ...
    "boundingBox",[NaN NaN NaN NaN],"confidence",0);
recognitionEventCount = 0;
recognitionDiagnostics = localEmptyRecognitionDiagnostics();
displayRefreshHz = 25;
if isfield(cfg,"display") && isfield(cfg.display,"refreshHz") && ...
        isfinite(double(cfg.display.refreshHz)) && double(cfg.display.refreshHz) > 0
    displayRefreshHz = double(cfg.display.refreshHz);
end
rgbRefreshHz = displayRefreshHz;
if isfield(cfg,"camera") && isfield(cfg.camera,"rgb") && ...
        isfield(cfg.camera.rgb,"previewFps") && ...
        isfinite(double(cfg.camera.rgb.previewFps)) && double(cfg.camera.rgb.previewFps) > 0
    rgbRefreshHz = double(cfg.camera.rgb.previewFps);
end

while toc(startTime) < cfg.runtime.durationSeconds
    if cfg.display.enabled && ~viewer.isRunning()
        break
    end
    viewer.pumpEvents();
    commands=viewer.consumeCommands();
    [stopRequested,displayAccumulationUs,startRequested]= ...
        app.readViewerCommandState(commands,displayAccumulationUs);
    viewer.setDisplayAccumulationUs(displayAccumulationUs);
    if stopRequested && running
        src.close();
        running=false;
        resetProcessingState();
        viewer.resetProcessingView();
        viewer.setRunningState(false);
        viewer.setConnectionStatus("相机已断开，可随时重新连接","未连接");
    end
    if startRequested && ~running
        resetProcessingState();
        try
            selectedSerial=connectWithDecision();
            running=true;
            viewer.setRunningState(true);
            viewer.setConnectionStatus("相机已就绪，正在实时取流","已连接");
            lastDisplay=tic;
        catch connectionError
            running=false;
            viewer.setRunningState(false);
            viewer.setConnectionStatus( ...
                "连接未完成："+string(connectionError.message),"错误");
        end
    end
    for commandIndex=1:numel(commands)
        command=commands{commandIndex};
        try
            switch command.type
                case "connectRgb"
                    if ~rgbRunning
                        ensureRgbSource();
                        viewer.setRgbConnectionStatus("正在枚举Hikrobot设备……","连接中");
                        devices = rgbSrc.discover();
                        preferred = "";
                        if isfield(cfg.camera,"rgb") && isfield(cfg.camera.rgb,"serial")
                            preferred = string(cfg.camera.rgb.serial);
                        end
                        serial = viewer.selectRgbCamera(devices,preferred);
                        viewer.setRgbConnectionStatus("正在连接："+serial,"连接中");
                        rgbSrc.open(serial);
                        rgbRunning = true;
                        viewer.setRgbRunningState(true);
                        viewer.setRgbCameraInfo(rgbSrc.getInfo());
                        if isfinite(rgbSrc.ExposureUs)
                            viewer.setRgbExposureState(rgbSrc.ExposureUs);
                        end
                        viewer.setRgbConnectionStatus("RGB相机已连接，正在实时取流","已连接");
                        lastRgbDisplay = tic;
                    end
                case "disconnectRgb"
                    if rgbRunning && ~isempty(rgbSrc)
                        rgbSrc.close();
                    end
                    rgbRunning = false;
                    viewer.setRgbRunningState(false);
                    viewer.setRgbCameraInfo(struct("serial","--","model","--"));
                    viewer.setRgbExposureState(NaN);
                    viewer.setRgbConnectionStatus("RGB相机已断开","未连接");
                case "setRgbExposureUs"
                    if ~rgbRunning || isempty(rgbSrc)
                        error("Hikrobot:NotOpen","RGB相机尚未连接。");
                    end
                    currentExposure = rgbSrc.setExposureUs(command.value);
                    viewer.setRgbExposureState(currentExposure);
                    viewer.setRgbConnectionStatus("RGB相机已连接，正在实时取流","已连接");
                case "setROI"
                    cfg=app.applyROICommand(cfg,command);
                    viewer.showROI(cfg.roi.rectangle);
                    if string(cfg.roi.mode) == "hardware"
                        src.setROI(cfg.roi.rectangle);
                    end
                    resetProcessingState();
                case "clearROI"
                    cfg=app.applyROICommand(cfg,command);
                    viewer.clearROI();
                    if string(cfg.roi.mode) == "hardware"
                        src.clearROI();
                    end
                    resetProcessingState();
                case "setDisplayAccumulationUs"
                    src.setDisplayAccumulation(command.value);
                    displayAccumulationUs = max(1000,min(100000, ...
                        round(double(command.value))));
                    cfg.display.accumulationUs = uint64(displayAccumulationUs);
                    viewer.setDisplayAccumulationUs(displayAccumulationUs);
                case "startRecording"
                    src.startRawRecording(cfg.recording.rawDirectory);
                    viewer.setRecordingState(true);
                case "stopRecording"
                    src.stopRawRecording();
                    viewer.setRecordingState(false);
                case "setToolParameter"
                    current=src.setToolParameter( ...
                        command.tool,command.name,command.value);
                    viewer.setToolParameterState(command.index,current);
            end
        catch commandError
            if string(command.type) == "setRgbExposureUs"
                if rgbRunning && ~isempty(rgbSrc) && rgbSrc.isConnected()
                    viewer.setRgbConnectionStatus( ...
                        "RGB已连接；曝光设置失败："+string(commandError.message),"已连接");
                else
                    try
                        if ~isempty(rgbSrc), rgbSrc.close(); end
                    catch
                    end
                    rgbRunning = false;
                    viewer.setRgbRunningState(false);
                    viewer.setRgbCameraInfo(struct("serial","--","model","--"));
                    viewer.setRgbExposureState(NaN);
                    viewer.setRgbConnectionStatus( ...
                        "RGB连接已丢失："+string(commandError.message),"错误");
                end
            elseif any(string(command.type) == ["connectRgb","disconnectRgb"])
                try
                    if ~isempty(rgbSrc), rgbSrc.close(); end
                catch
                end
                rgbRunning = false;
                viewer.setRgbRunningState(false);
                viewer.setRgbCameraInfo(struct("serial","--","model","--"));
                viewer.setRgbExposureState(NaN);
                viewer.setRgbConnectionStatus( ...
                    "RGB命令失败："+string(commandError.message),"错误");
            else
                viewer.setCommandError(command,commandError.message);
            end
        end
    end
    if rgbRunning && ~isempty(rgbSrc) && ...
            cfg.display.enabled && toc(lastRgbDisplay) >= 1/rgbRefreshHz
        try
            rgbFrame = rgbSrc.readDisplayFrame();
            if ~isempty(rgbFrame)
                viewer.updateRgb(rgbFrame);
            end
        catch rgbReadError
            try, rgbSrc.close(); catch, end
            rgbRunning = false;
            viewer.setRgbRunningState(false);
            viewer.setRgbCameraInfo(struct("serial","--","model","--"));
            viewer.setRgbExposureState(NaN);
            viewer.setRgbConnectionStatus( ...
                "RGB取流失败："+string(rgbReadError.message),"错误");
        end
        lastRgbDisplay = tic;
    end

    if ~running
        pause(0.01);
        continue
    end
    if ~src.hasData()
        pause(0.01);
        continue
    end

    iteration = tic;
    packet = src.read();
    sequence = sequence + 1;
    packet.sequence = sequence;

    packet = analysis.applyROI(packet,cfg.roi);
    recognitionAccumulator.add(packet);
    recognitionStatus = "waiting-window";
    recognitionReason = "事件窗口尚未就绪。";
    if recognitionAccumulator.ready()
        recognitionPacket=recognitionAccumulator.take();
        recognitionPacket.rawEventCount = numel(recognitionPacket.x);
        recognitionPacket=recognitionFilter.apply(recognitionPacket,cfg);
        recognitionPacket.filteredEventCount = numel(recognitionPacket.x);
        riserResult = riserBackend.process(recognitionPacket);
        riserResult = analysis.applyRoiOffset( ...
            riserResult,recognitionPacket.roiOffset);
        recognitionStatus = string(localField(riserResult,"status","invalid"));
        recognitionReason = string(localField(riserResult,"reason","未能生成识别结果。"));
        measurement = struct( ...
            "valid",riserResult.valid, ...
            "position",riserResult.position, ...
            "boundingBox",localBoundingBox(riserResult), ...
            "confidence",riserResult.confidence);
        track = tracker.step(measurement,recognitionPacket.timeEndUs);
        if riserResult.valid
            track.velocity=riserResult.velocity;
        end
        recognitionEventCount=numel(recognitionPacket.x);
        recognitionDiagnostics = localRecognitionDiagnostics(riserResult);
        viewer.setAnalysisResult(riserResult,track,localBackendState());
    end

    latencyUs = toc(iteration)*1e6;
    stats = struct("latencyUs",latencyUs, ...
        "timestampUs",packet.timeEndUs, ...
        "eventCount",numel(packet.timestamp), ...
        "eventRate",localEventRate(packet), ...
        "recognitionEventCount",recognitionEventCount, ...
        "recognitionStatus",recognitionStatus, ...
        "recognitionReason",recognitionReason, ...
        "recognitionDiagnostics",recognitionDiagnostics, ...
        "backend",riserBackend.Name+" / "+backend.Name, ...
        "deadlineMiss",latencyUs > cfg.runtime.warningLatencyUs);

    recorder.write(packet,track,stats);

    if cfg.display.enabled && toc(lastDisplay) >= 1/displayRefreshHz
        frame = src.readDisplayFrame();
        viewer.update(frame,track,stats);
        lastDisplay = tic;
        if ~viewer.isRunning(), break; end
    end
end

    function shutdown
        try
            recorder.close();
        catch
        end
        try
            src.stopRawRecording();
        catch
        end
        try
            src.close();
        catch
        end
        try
            if ~isempty(rgbSrc), rgbSrc.close(); end
        catch
        end
        try
            delete(viewer);
        catch
        end
    end
    function ensureRgbSource
        if isempty(rgbSrc) || ~isvalid(rgbSrc)
            rgbSrc = camera.HikrobotCameraSource(cfg);
        end
    end

    function serial=selectCamera
        viewer.setConnectionStatus("正在枚举DVSLume设备……","连接中");
        devices=src.discover();
        if isempty(devices)
            try
                helpers=src.listStaleHelpers();
                if ~isempty(helpers)
                    src.terminateStaleHelpers();
                    viewer.setConnectionStatus( ...
                        "未发现相机，已清理本项目残留helper后重新枚举……","连接中");
                end
            catch cleanupError %#ok<NASGU>
            end
            pause(0.2);
            devices=src.discover();
        end
        serial=viewer.selectCamera(devices,string(selectedSerialOrConfigured()));
        viewer.setConnectionStatus( ...
            "已发现设备，准备连接："+serial,"连接中");
    end
    function serial=connectWithDecision
        while true
            try
                serial=selectCamera();
                startSource(serial);
                return
            catch connectionError
                try
                    src.close();
                catch
                end
                action=viewer.resolveConnectionFailure(connectionError);
                switch action
                    case "重新扫描"
                        continue
                    case "清理本项目残留helper"
                        helpers=src.listStaleHelpers();
                        if isempty(helpers)
                            viewer.setConnectionStatus( ...
                                "未发现本项目残留helper","错误");
                        else
                            src.terminateStaleHelpers();
                            viewer.setConnectionStatus( ...
                                "已清理本项目残留helper，准备重新扫描","连接中");
                        end
                        continue
                    otherwise
                        rethrow(connectionError)
                end
            end
        end
    end
    function serial=selectedSerialOrConfigured
        serial="";
        if exist("selectedSerial","var") && strlength(string(selectedSerial))>0
            serial=string(selectedSerial);
        elseif isfield(cfg.camera,"serial")
            serial=string(cfg.camera.serial);
        end
    end
    function startSource(serial)
        try
            src.open(serial);
        catch connectionError
            viewer.setConnectionStatus("连接失败："+string(connectionError.message),"错误");
            rethrow(connectionError)
        end
        cameraInfo=src.getInfo();
        viewer.setCameraInfo(cameraInfo);
        viewer.setToolParameters(src.getToolParameters());
        src.setBatchTime(batchTimeUs);
        src.setDisplayAccumulation(displayAccumulationUs);
    end
    function resetProcessingState
        recognitionAccumulator.reset();
        tracker.reset();
        recognitionFilter=analysis.ActivityFilter;
        if ismethod(riserBackend,"reset"), riserBackend.reset(); end
        recognitionEventCount=0;
        track=struct("valid",false,"timestampUs",uint64(0), ...
            "position",[NaN;NaN],"velocity",[NaN;NaN], ...
            "boundingBox",[NaN NaN NaN NaN],"confidence",0);
        recognitionDiagnostics=localEmptyRecognitionDiagnostics();
    end
    function state=localBackendState
        if ismethod(riserBackend,"status")
            state=riserBackend.status();
        else
            state=struct("requested",string(cfg.compute.backend), ...
                "executed",string(riserBackend.Name), ...
                "fallback",false,"reason","");
        end
    end
    function box=localBoundingBox(result)
        points = zeros(0,2);
        if isstruct(result) && isfield(result,"outline") && ~isempty(result.outline)
            points = double(result.outline);
        elseif isstruct(result) && isfield(result,"mask") && any(result.mask(:))
            [rows,columns] = find(result.mask);
            points = [double(columns),double(rows)];
        elseif isstruct(result) && isfield(result,"centerline") && ~isempty(result.centerline)
            points = double(result.centerline);
        end
        if isempty(points)
            box=[NaN NaN NaN NaN];
            return
        end
        minimum=min(points,[],1);
        maximum=max(points,[],1);
        box=[minimum maximum-minimum+1];
    end
    function rate=localEventRate(packet)
        rate=0;
        durationUs=double(packet.timeEndUs)-double(packet.timeStartUs);
        if durationUs>0
            rate=double(numel(packet.timestamp))/(durationUs/1e6);
        end
    end
    function value=localField(valueStruct,field,defaultValue)
        value=defaultValue;
        if isstruct(valueStruct) && isfield(valueStruct,field)
            value=valueStruct.(field);
        end
    end
    function value=localRecognitionMinEvents
        value=20;
        if isfield(cfg,"tracking") && isfield(cfg.tracking,"minimumEvents")
            value=max(1,round(double(cfg.tracking.minimumEvents)));
        end
        if isfield(cfg,"processing") && isfield(cfg.processing,"recognitionMinEvents")
            value=max(1,round(double(cfg.processing.recognitionMinEvents)));
        end
    end
    function value=localEmptyRecognitionDiagnostics
        value=struct("rawEventCount",0,"filteredEventCount",0, ...
            "maskPixelCount",0,"outlinePointCount",0, ...
            "centerlinePointCount",0);
    end
    function value=localRecognitionDiagnostics(result)
        value=struct( ...
            "rawEventCount",double(localField(result,"rawEventCount",0)), ...
            "filteredEventCount",double(localField(result,"filteredEventCount",0)), ...
            "maskPixelCount",double(localField(result,"maskPixelCount",0)), ...
            "outlinePointCount",double(localField(result,"outlinePointCount",0)), ...
            "centerlinePointCount",double(localField(result,"centerlinePointCount",0)));
    end
end
