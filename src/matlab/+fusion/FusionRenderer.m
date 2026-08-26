classdef FusionRenderer < handle
    properties (SetAccess = private)
        RgbThreshold double = 0
        CalibrationValid logical = false
        CalibrationReason string = "未加载标定"
    end

    properties (Access = private)
        Config struct
        Homography double = eye(3)
        OutputWidth double = 1280
        OutputHeight double = 720
    end

    methods
        function obj = FusionRenderer(cfg)
            arguments
                cfg struct
            end
            obj.Config = cfg;
            if isfield(cfg,"fusion")
                if isfield(cfg.fusion,"outputWidth")
                    obj.OutputWidth = double(cfg.fusion.outputWidth);
                end
                if isfield(cfg.fusion,"outputHeight")
                    obj.OutputHeight = double(cfg.fusion.outputHeight);
                end
                if isfield(cfg.fusion,"rgbThreshold")
                    obj.RgbThreshold = obj.normalizeThreshold(cfg.fusion.rgbThreshold);
                end
            end
            obj.reloadCalibration();
        end

        function result = render(obj,dvsFrame,rgbFrame,inputState)
            arguments
                obj
                dvsFrame = []
                rgbFrame = []
                inputState struct = struct()
            end

            result = obj.emptyResult();
            dvsAvailable = ~isempty(dvsFrame);
            rgbAvailable = ~isempty(rgbFrame);
            if isfield(inputState,"dvsAvailable")
                dvsAvailable = logical(inputState.dvsAvailable);
            end
            if isfield(inputState,"rgbAvailable")
                rgbAvailable = logical(inputState.rgbAvailable);
            end

            if ~dvsAvailable || isempty(dvsFrame)
                result.status = "waiting-dvs";
                result.reason = "等待 DVS 最新显示帧。";
                return
            end
            if ~rgbAvailable || isempty(rgbFrame)
                result.status = "waiting-rgb";
                result.reason = "等待 RGB 最新预览帧。";
                return
            end
            if ~obj.CalibrationValid
                result.status = "calibration-error";
                result.reason = obj.CalibrationReason;
                return
            end

            try
                rgbFrame = fusion.applyRgbThreshold(rgbFrame,obj.RgbThreshold);
                warped = obj.warpRgb(rgbFrame);
                frame = obj.overlayEvents(warped,dvsFrame);
                result.frame = frame;
                result.valid = true;
                result.status = "ready";
                result.reason = "Fusion 就绪";
            catch cause
                result.status = "calibration-error";
                result.reason = "Fusion 渲染失败：" + string(cause.message);
            end
        end

        function value = setRgbThreshold(obj,value)
            obj.RgbThreshold = obj.normalizeThreshold(value);
            value = obj.RgbThreshold;
        end

        function reset(obj)
            obj.RgbThreshold = 0;
        end

        function reloadCalibration(obj)
            obj.CalibrationValid = false;
            obj.CalibrationReason = "Fusion 标定未启用。";
            obj.Homography = eye(3);

            if ~isfield(obj.Config,"fusion") || ...
                    ~isfield(obj.Config.fusion,"calibrationEnabled") || ...
                    ~logical(obj.Config.fusion.calibrationEnabled)
                return
            end
            if ~isfield(obj.Config.fusion,"calibrationFile")
                obj.CalibrationReason = "Fusion 配置缺少 calibrationFile。";
                return
            end

            loaded = fusion.loadRgbToDvsTransform( ...
                string(obj.Config.fusion.calibrationFile));
            obj.CalibrationValid = logical(loaded.valid);
            obj.CalibrationReason = string(loaded.reason);
            if obj.CalibrationValid
                obj.Homography = double(loaded.matrix);
            end
        end
    end

    methods (Access = private)
        function result = emptyResult(obj)
            result = struct( ...
                "frame",zeros(0,0,3,"uint8"), ...
                "valid",false, ...
                "status","calibration-error", ...
                "reason",obj.CalibrationReason, ...
                "calibrationValid",obj.CalibrationValid, ...
                "rgbThreshold",obj.RgbThreshold);
        end

        function warped = warpRgb(obj,rgbFrame)
            if ~isa(rgbFrame,"uint8")
                rgbFrame = im2uint8(rgbFrame);
            end
            if ndims(rgbFrame) == 2
                rgbFrame = repmat(rgbFrame,1,1,3);
            end
            if size(rgbFrame,3) ~= 3
                error("DVSense:FusionRgbShape","RGB frame must be HxWx3.");
            end

            if exist("projective2d","class") ~= 8 || exist("imwarp","file") ~= 2
                error("DVSense:FusionImageToolbox", ...
                    "Fusion requires projective2d and imwarp from Image Processing Toolbox.");
            end
            transform = projective2d(obj.Homography.');
            outputView = imref2d([obj.OutputHeight obj.OutputWidth]);
            warped = imwarp(rgbFrame,transform,"OutputView",outputView, ...
                "Interp","linear","FillValues",0);
            if ~isa(warped,"uint8")
                warped = im2uint8(warped);
            end
        end

        function frame = overlayEvents(obj,rgbFrame,dvsFrame)
            expected = [obj.OutputHeight obj.OutputWidth];
            if ~isequal(size(dvsFrame,1),expected(1)) || ...
                    ~isequal(size(dvsFrame,2),expected(2))
                error("DVSense:FusionDvsShape", ...
                    "DVS display frame must be %dx%d.",expected(1),expected(2));
            end
            if ndims(dvsFrame) ~= 2
                error("DVSense:FusionDvsShape", ...
                    "DVS display frame must be a 2-D indexed frame.");
            end

            frame = rgbFrame;
            onMask = dvsFrame == 2;
            offMask = dvsFrame == 3;

            red = frame(:,:,1);
            green = frame(:,:,2);
            blue = frame(:,:,3);

            red(onMask) = 0;
            green(onMask) = 255;
            blue(onMask) = 0;

            red(offMask) = 255;
            green(offMask) = 0;
            blue(offMask) = 255;

            frame(:,:,1) = red;
            frame(:,:,2) = green;
            frame(:,:,3) = blue;
        end

        function value = normalizeThreshold(~,value)
            value = double(value);
            if ~isscalar(value) || ~isfinite(value)
                error("DVSense:FusionThreshold", ...
                    "RGB brightness threshold must be one finite scalar.");
            end
            value = round(max(0,min(255,value)));
        end
    end
end
