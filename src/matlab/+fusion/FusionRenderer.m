classdef FusionRenderer < handle
    properties (SetAccess = private)
        OutputWidth double = 1280
        OutputHeight double = 720
        EventAlpha double = 1.0
    end

    methods
        function obj = FusionRenderer(cfg)
            arguments
                cfg struct
            end
            if isfield(cfg,"fusion")
                if isfield(cfg.fusion,"outputWidth")
                    obj.OutputWidth = max(1,round(double(cfg.fusion.outputWidth)));
                end
                if isfield(cfg.fusion,"outputHeight")
                    obj.OutputHeight = max(1,round(double(cfg.fusion.outputHeight)));
                end
                if isfield(cfg.fusion,"eventAlpha")
                    value = double(cfg.fusion.eventAlpha);
                    if isscalar(value) && isfinite(value)
                        obj.EventAlpha = max(0,min(1,value));
                    end
                end
            end
        end

        function result = render(obj,dvsFrame,rgbFrame)
            result = struct("frame",zeros(0,0,3,"uint8"), ...
                "valid",false,"status","waiting-dvs", ...
                "reason","等待 DVS 最新显示帧。");

            if isempty(dvsFrame)
                return
            end
            if isempty(rgbFrame)
                result.status = "waiting-rgb";
                result.reason = "等待 RGB 最新显示帧。";
                return
            end

            try
                base = obj.prepareRgb(rgbFrame);
                [onMask,offMask] = obj.eventMasks(dvsFrame);
                frame = obj.overlay(base,onMask,offMask);
                result.frame = frame;
                result.valid = true;
                result.status = "ready";
                result.reason = "Fusion 正在复用 DVS/RGB 最新显示帧。";
            catch cause
                result.status = "error";
                result.reason = "Fusion 渲染失败：" + string(cause.message);
            end
        end
    end

    methods (Access = private)
        function frame = prepareRgb(obj,frame)
            if ndims(frame) == 2
                frame = repmat(frame,1,1,3);
            end
            if ndims(frame) ~= 3 || size(frame,3) ~= 3
                error("DVSense:FusionRgbShape","RGB frame must be HxWx3.");
            end
            if ~isa(frame,"uint8")
                if isfloat(frame)
                    if max(frame(:),[],"omitnan") <= 1
                        frame = uint8(max(0,min(1,frame))*255);
                    else
                        frame = uint8(max(0,min(255,frame)));
                    end
                else
                    frame = uint8(frame);
                end
            end
            if size(frame,1) ~= obj.OutputHeight || size(frame,2) ~= obj.OutputWidth
                frame = obj.resizeNearest(frame,obj.OutputHeight,obj.OutputWidth);
            end
        end

        function [onMask,offMask] = eventMasks(obj,dvsFrame)
            if size(dvsFrame,1) ~= obj.OutputHeight || size(dvsFrame,2) ~= obj.OutputWidth
                dvsFrame = obj.resizeNearest(dvsFrame,obj.OutputHeight,obj.OutputWidth);
            end
            if ndims(dvsFrame) == 2
                onMask = dvsFrame == 2;
                offMask = dvsFrame == 3;
                return
            end
            if ndims(dvsFrame) ~= 3 || size(dvsFrame,3) ~= 3
                error("DVSense:FusionDvsShape", ...
                    "DVS frame must be indexed HxW or RGB HxWx3.");
            end
            value = double(dvsFrame);
            red = value(:,:,1);
            green = value(:,:,2);
            blue = value(:,:,3);
            onMask = green > red + 20 & green > blue + 20;
            offMask = red > green + 20 & blue > green + 20;
        end

        function frame = overlay(obj,base,onMask,offMask)
            frame = double(base);
            alpha = obj.EventAlpha;
            onColor = reshape([0 255 0],[1 1 3]);
            offColor = reshape([255 0 255],[1 1 3]);
            for channel = 1:3
                plane = frame(:,:,channel);
                target = onColor(1,1,channel);
                plane(onMask) = (1-alpha)*plane(onMask) + alpha*target;
                target = offColor(1,1,channel);
                plane(offMask) = (1-alpha)*plane(offMask) + alpha*target;
                frame(:,:,channel) = plane;
            end
            frame = uint8(max(0,min(255,round(frame))));
        end

        function output = resizeNearest(~,input,newHeight,newWidth)
            oldHeight = size(input,1);
            oldWidth = size(input,2);
            rows = min(oldHeight,max(1,round(linspace(1,oldHeight,newHeight))));
            columns = min(oldWidth,max(1,round(linspace(1,oldWidth,newWidth))));
            if ndims(input) == 2
                output = input(rows,columns);
            else
                output = input(rows,columns,:);
            end
        end
    end
end
