classdef DVSenseSession < handle
    properties (Access=private)
        Alias string = "dvsense_bridge"
        LibraryPath string
        Opened logical = false
        Started logical = false
        EventCapacity double = 200000
        EventX
        EventY
        EventPolarity
        EventTimestamp
        EventCount
        FrameBuffer
        FrameWidth
        FrameHeight
        Info struct = struct()
        Parameters struct = struct([])
    end
    methods
        function obj=DVSenseSession(runtimeDir,eventCapacity)
            arguments
                runtimeDir (1,1) string
                eventCapacity (1,1) double = 200000
            end
            obj.LibraryPath=fullfile(runtimeDir,"dvsense_bridge.dll");
            obj.EventCapacity=max(1,floor(eventCapacity));
            obj.EventX=libpointer("uint16Ptr",zeros(obj.EventCapacity,1,"uint16"));
            obj.EventY=libpointer("uint16Ptr",zeros(obj.EventCapacity,1,"uint16"));
            obj.EventPolarity=libpointer("uint8Ptr",zeros(obj.EventCapacity,1,"uint8"));
            obj.EventTimestamp=libpointer("uint64Ptr",zeros(obj.EventCapacity,1,"uint64"));
            obj.EventCount=libpointer("uint32Ptr",0);
            obj.FrameBuffer=libpointer("uint8Ptr",zeros(1280*720,1,"uint8"));
            obj.FrameWidth=libpointer("uint32Ptr",0);
            obj.FrameHeight=libpointer("uint32Ptr",0);
        end
        function open(obj,serial)
            arguments
                obj
                serial (1,1) string = ""
            end
            obj.ensureLoaded();
            obj.callStatus("dvsense_open",char(serial));
            obj.Opened=true;
            obj.Info=obj.readJson("dvsense_get_camera_info_json");
            obj.Parameters=obj.readJson("dvsense_get_tool_parameters_json");
        end
        function devices=discover(obj)
            obj.ensureLoaded();
            raw=calllib(obj.Alias,"dvsense_discover_cameras_json");
            errorText=obj.readCString("dvsense_last_error");
            if strlength(errorText)>0
                error("DVSense:Discovery", "%s",errorText);
            end
            devices=jsondecode(raw);
            if isempty(devices)
                devices=struct([]);
            end
        end
        function helpers=listStaleHelpers(obj)
            obj.ensureLoaded();
            raw=calllib(obj.Alias,"dvsense_list_stale_helpers_json");
            errorText=obj.readCString("dvsense_last_error");
            if strlength(errorText)>0
                error("DVSense:Recovery", "%s",errorText);
            end
            helpers=jsondecode(raw);
            if isempty(helpers)
                helpers=struct([]);
            end
        end
        function terminateStaleHelpers(obj)
            obj.ensureLoaded();
            status=calllib(obj.Alias,"dvsense_terminate_stale_helpers");
            if double(status)~=0
                error("DVSense:Recovery", "%s", ...
                    obj.readCString("dvsense_last_error"));
            end
        end
        function start(obj)
            obj.requireOpened();
            obj.callStatus("dvsense_start");
            obj.Started=true;
        end
        function stop(obj)
            if obj.Opened
                obj.callStatus("dvsense_stop");
                obj.Started=false;
            end
        end
        function close(obj)
            if obj.Opened
                try
                    obj.stop();
                catch
                end
                try
                    obj.callStatus("dvsense_close");
                catch
                end
                obj.Opened=false;
            elseif libisloaded(obj.Alias)
                try
                    obj.callStatus("dvsense_close");
                catch
                end
            end
            if libisloaded(obj.Alias)
                unloadlibrary(obj.Alias);
            end
        end
        function setBatchTime(obj,windowUs)
            obj.requireOpened();
            obj.callStatus("dvsense_set_batch_time",uint64(windowUs));
        end
        function setDisplayWindow(obj,windowUs)
            obj.requireOpened();
            value=max(uint64(1000),min(uint64(100000),uint64(windowUs)));
            obj.callStatus("dvsense_set_display_window",value);
        end
        function setROI(obj,rectangle)
            obj.requireOpened();
            obj.callStatus("dvsense_set_roi",int32(rectangle(1)),int32(rectangle(2)), ...
                int32(rectangle(3)),int32(rectangle(4)));
        end
        function packet=readEvents(obj)
            obj.requireOpened();
            obj.callStatus("dvsense_read_events",obj.EventX,obj.EventY, ...
                obj.EventPolarity,obj.EventTimestamp,uint32(obj.EventCapacity), ...
                obj.EventCount);
            n=double(obj.EventCount.Value);
            packet=struct( ...
                "x",obj.EventX.Value(1:n), ...
                "y",obj.EventY.Value(1:n), ...
                "polarity",logical(obj.EventPolarity.Value(1:n)), ...
                "timestamp",obj.EventTimestamp.Value(1:n));
            packet.resolution=[double(obj.Info.height),double(obj.Info.width)];
            packet.roiOffset=[0 0];
            if n==0
                packet.timeStartUs=uint64(0);
                packet.timeEndUs=uint64(0);
            else
                packet.timeStartUs=min(packet.timestamp);
                packet.timeEndUs=max(packet.timestamp);
            end
        end
        function frame=readDisplayFrame(obj)
            obj.requireOpened();
            pixels=double(obj.Info.width)*double(obj.Info.height);
            if numel(obj.FrameBuffer.Value)<pixels
                obj.FrameBuffer=libpointer("uint8Ptr",zeros(pixels,1,"uint8"));
            end
            obj.callStatus("dvsense_read_frame",obj.FrameBuffer,uint32(pixels), ...
                obj.FrameWidth,obj.FrameHeight);
            width=double(obj.FrameWidth.Value);
            height=double(obj.FrameHeight.Value);
            frame=reshape(obj.FrameBuffer.Value(1:width*height),[width height]).';
        end
        function current=setParameter(obj,tool,name,value)
            obj.requireOpened();
            parameter=obj.findParameter(tool,name);
            typed=camera.validateToolParameter(parameter,value);
            type=upper(string(parameter.type));
            text=camera.formatToolParameterValue(typed,type);
            obj.callStatus("dvsense_set_parameter",char(string(tool)), ...
                char(string(name)),char(type),text);
            current=string(obj.readCString("dvsense_last_value"));
            obj.Parameters=obj.readJson("dvsense_get_tool_parameters_json");
        end
        function startRecording(obj,path)
            obj.requireOpened();
            obj.callStatus("dvsense_start_recording",char(path));
        end
        function stopRecording(obj)
            if obj.Opened
                obj.callStatus("dvsense_stop_recording");
            end
        end
        function info=getInfo(obj), info=obj.Info; end
        function parameters=getToolParameters(obj), parameters=obj.Parameters; end
        function delete(obj)
            try
                obj.close();
            catch
            end
        end
    end
    methods (Access=private)
        function ensureLoaded(obj)
            if libisloaded(obj.Alias), return; end
            assert(isfile(obj.LibraryPath),"DVSense bridge DLL not found: %s",obj.LibraryPath);
            loadlibrary(obj.LibraryPath,@camera.internal.dvsenseBridgePrototype, ...
                "alias",obj.Alias);
        end
        function requireOpened(obj)
            assert(obj.Opened,"DVSense相机尚未打开。");
        end
        function callStatus(obj,functionName,varargin)
            status=calllib(obj.Alias,functionName,varargin{:});
            if double(status)~=0
                error("DVSense:Bridge", "%s", obj.readCString("dvsense_last_error"));
            end
        end
        function value=readJson(obj,functionName)
            value=jsondecode(obj.readCString(functionName));
        end
        function text=readCString(obj,functionName)
            raw=calllib(obj.Alias,functionName);
            if ischar(raw)
                text=string(raw);
            elseif isa(raw,"lib.pointer")
                text=string(char(raw.Value));
            else
                text=string(raw);
            end
        end
        function parameter=findParameter(obj,tool,name)
            matches=strcmp(string({obj.Parameters.tool}),string(tool)) & ...
                strcmp(string({obj.Parameters.name}),string(name));
            assert(nnz(matches)==1,"DVSense:ParameterNotFound", ...
                "未找到SDK参数：%s/%s",tool,name);
            parameter=obj.Parameters(matches);
        end
    end
end
