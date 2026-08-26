classdef HikrobotCameraSource < handle
    properties (SetAccess = private)
        Config struct
        Opened logical = false
        SelectedSerial string = ""
        Info struct = struct()
        ExposureUs double = NaN
    end
    properties (Access = private)
        OriginalPath string = ""
        ReadTimeoutMs double = 20
        PreviewWidth double = 1280
        PreviewHeight double = 720
    end

    methods
        function obj = HikrobotCameraSource(cfg)
            obj.Config = cfg;
            obj.configurePreview();
            obj.prepareRuntime();
        end

        function devices = discover(obj)
            obj.requireMex();
            devices = hikrobot_mex("discover");
        end

        function open(obj,selectedSerial)
            arguments
                obj
                selectedSerial (1,1) string = ""
            end
            obj.requireMex();
            if strlength(selectedSerial) == 0
                devices = obj.discover();
                selectedSerial = obj.selectSerial(devices);
            end
            info = hikrobot_mex("open",selectedSerial);
            obj.Opened = true;
            obj.SelectedSerial = string(info.serial);
            obj.Info = info;
            try
                obj.ExposureUs = double(hikrobot_mex("getExposure"));
            catch
                obj.ExposureUs = NaN;
            end
            if isfield(obj.Config.camera,"rgb") && ...
                    isfield(obj.Config.camera.rgb,"exposureUs") && ...
                    isfinite(double(obj.Config.camera.rgb.exposureUs))
                obj.setExposureUs(double(obj.Config.camera.rgb.exposureUs));
            end
        end

        function tf = hasData(obj)
            tf = obj.Opened;
        end

        function tf = isConnected(obj)
            tf = false;
            if ~obj.Opened, return, end
            try
                info = hikrobot_mex("info");
                tf = logical(info.connected);
                obj.Info = info;
            catch
                tf = false;
            end
        end

        function frame = readDisplayFrame(obj)
            assert(obj.Opened,"RGB相机尚未连接。");
            frame = hikrobot_mex("read",obj.ReadTimeoutMs, ...
                obj.PreviewWidth,obj.PreviewHeight);
        end

        function current = setExposureUs(obj,value)
            value = double(value);
            if ~isscalar(value) || ~isfinite(value) || value <= 0
                error("Hikrobot:Exposure","曝光时间必须是正数（微秒）。");
            end
            assert(obj.Opened,"RGB相机尚未连接。");
            current = double(hikrobot_mex("setExposure",value));
            obj.ExposureUs = current;
        end

        function info = getInfo(obj)
            info = obj.Info;
            if obj.Opened
                try
                    info = hikrobot_mex("info");
                    obj.Info = info;
                catch
                end
            end
        end

        function close(obj)
            if obj.Opened
                try, hikrobot_mex("close"); catch, end
            end
            obj.Opened = false;
            obj.SelectedSerial = "";
            obj.Info = struct();
            obj.ExposureUs = NaN;
        end

        function delete(obj)
            try, obj.close(); catch, end
            if strlength(obj.OriginalPath) > 0
                try, setenv("PATH",obj.OriginalPath); catch, end
            end
        end
    end

    methods (Access = private)
        function configurePreview(obj)
            if ~isfield(obj.Config,"camera") || ~isfield(obj.Config.camera,"rgb")
                return
            end
            rgb = obj.Config.camera.rgb;
            if isfield(rgb,"readTimeoutMs") && isfinite(double(rgb.readTimeoutMs))
                obj.ReadTimeoutMs = max(1,min(1000,round(double(rgb.readTimeoutMs))));
            end
            if isfield(rgb,"previewWidth") && isfinite(double(rgb.previewWidth))
                obj.PreviewWidth = max(1,round(double(rgb.previewWidth)));
            end
            if isfield(rgb,"previewHeight") && isfinite(double(rgb.previewHeight))
                obj.PreviewHeight = max(1,round(double(rgb.previewHeight)));
            end
        end

        function prepareRuntime(obj)
            obj.OriginalPath = string(getenv("PATH"));
            runtimeRoot = "C:\Program Files (x86)\Common Files\MVS\Runtime\Win64_x64";
            if isfield(obj.Config,"paths") && isfield(obj.Config.paths,"mvsRuntimeRoot")
                runtimeRoot = string(obj.Config.paths.mvsRuntimeRoot);
            end
            if ~isfolder(runtimeRoot)
                error("Hikrobot:MvsRuntime","MVS运行库目录不存在：%s",runtimeRoot);
            end
            current = string(getenv("PATH"));
            entries = split(current,pathsep);
            if ~any(strcmpi(entries,runtimeRoot))
                setenv("PATH",runtimeRoot+pathsep+current);
            end
        end

        function requireMex(obj)
            if exist("hikrobot_mex","file") ~= 3
                mvsRoot = "<未配置>";
                if isfield(obj.Config,"paths") && isfield(obj.Config.paths,"mvsRoot")
                    mvsRoot = string(obj.Config.paths.mvsRoot);
                end
                error("Hikrobot:MexMissing", ...
                    "未找到hikrobot_mex。请先运行 tools/build/buildHikrobotMex.m。MVS根目录：%s", ...
                    mvsRoot);
            end
        end

        function serial = selectSerial(obj,devices)
            if isempty(devices)
                error("Hikrobot:NoCamera","未发现Hikrobot RGB相机。");
            end
            serials = string({devices.serial});
            preferred = "";
            if isfield(obj.Config.camera,"rgb") && isfield(obj.Config.camera.rgb,"serial")
                preferred = string(obj.Config.camera.rgb.serial);
            end
            index = find(serials == preferred,1);
            if ~isempty(index)
                serial = serials(index);
            else
                serial = serials(1);
            end
        end
    end
end
