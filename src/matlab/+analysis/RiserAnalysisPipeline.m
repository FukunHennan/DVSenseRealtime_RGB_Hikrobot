classdef RiserAnalysisPipeline < handle
    properties (SetAccess=private)
        Config struct
    end
    properties (Access=private)
        LastValid logical = false
        LastTimestampUs uint64 = uint64(0)
        LastPosition double = [NaN;NaN]
        LastVelocity double = [0;0]
    end
    methods
        function obj = RiserAnalysisPipeline(config)
            if nargin < 1, config = struct; end
            obj.Config = config;
        end

        function result = process(obj,packet)
            result = obj.emptyResult(packet);
            result.rawEventCount = obj.scalarField(packet,"rawEventCount",numel(packet.x));
            result.filteredEventCount = obj.scalarField(packet,"filteredEventCount",numel(packet.x));
            if result.rawEventCount == 0
                result.status = "waiting-events";
                result.reason = "当前识别窗口没有事件。";
                return
            end

            [eventImage,timeSurface] = analysis.riser.buildEventImage(packet,obj.processingConfig());
            [mask,primaryMask] = analysis.riser.segmentRiser(eventImage, ...
                obj.processingConfig(),timeSurface);
            result.mask = mask;
            result.maskPixelCount = nnz(mask);
            if ~any(mask(:))
                result.status = "mask-empty";
                result.reason = "活动滤波后未分割出目标。";
                obj.resetMotion();
                return
            end
            result.outline = analysis.riser.extractOutline(mask);
            result.outlinePointCount = obj.finitePointCount(result.outline);
            if isempty(result.outline)
                result.status = "outline-empty";
                result.reason = "已分割出目标，但未提取到轮廓。";
                obj.resetMotion();
                return
            end
            if ~any(primaryMask(:))
                primaryMask = mask;
            end
            result.outlines = result.outline;
            result.outline = analysis.riser.extractOutline(primaryMask);
            [centerline,curvature] = analysis.riser.extractCenterline(primaryMask, ...
                obj.processingConfig());
            result.centerlinePointCount = size(centerline,1);
            if isempty(centerline)
                result.status = "centerline-empty";
                result.reason = "已分割出目标，但未提取到中心线。";
                obj.resetMotion();
                return
            end
            motion = analysis.riser.estimateMotionState(centerline,packet.timeEndUs, ...
                obj.previousMotion(),obj.trackingConfig());
            result.valid = true;
            result.timestampUs = packet.timeEndUs;
            result.centerline = centerline;
            result.curvature = curvature;
            result.position = motion.position;
            result.velocity = motion.velocity;
            result.acceleration = motion.acceleration;
            result.confidence = obj.confidence(mask,packet);
            result.state = motion.state;
            result.status = "valid";
            result.reason = "轮廓与中心线已识别。";
            result.windowReady = true;
            obj.LastValid = true;
            obj.LastTimestampUs = packet.timeEndUs;
            obj.LastPosition = motion.position;
            obj.LastVelocity = motion.velocity;
        end
        function reset(obj)
            obj.resetMotion();
        end
    end
    methods (Access=private)
        function config = processingConfig(obj)
            config = struct;
            if isfield(obj.Config,"processing"), config = obj.Config.processing; end
        end
        function config = trackingConfig(obj)
            config = struct;
            if isfield(obj.Config,"tracking"), config = obj.Config.tracking; end
        end
        function previous = previousMotion(obj)
            previous = struct("valid",obj.LastValid,"timestampUs",obj.LastTimestampUs, ...
                "position",obj.LastPosition,"velocity",obj.LastVelocity);
        end
        function resetMotion(obj)
            obj.LastValid = false; obj.LastTimestampUs = uint64(0);
            obj.LastPosition = [NaN;NaN]; obj.LastVelocity = [0;0];
        end
        function confidence = confidence(obj,mask,packet)
            areaScore = min(1,nnz(mask) / max(1,numel(mask) * 0.04));
            eventScore = min(1,numel(packet.x) / max(1,obj.eventLimit()));
            confidence = 0.7 * areaScore + 0.3 * eventScore;
        end
        function limit = eventLimit(obj)
            limit = 1000;
            if isfield(obj.Config,"source") && isfield(obj.Config.source,"eventsPerWindow")
                limit = max(1,double(obj.Config.source.eventsPerWindow));
            end
        end
        function count = finitePointCount(~,points)
            if isempty(points)
                count = 0;
                return
            end
            if isvector(points)
                count = sum(isfinite(points));
                return
            end
            count = sum(all(isfinite(points),2));
        end
        function result = emptyResult(~,packet)
            resolution = double(packet.resolution);
            result = struct("valid",false,"timestampUs",packet.timeEndUs, ...
                "mask",false(resolution),"outline",zeros(0,2), ...
                "outlines",zeros(0,2), ...
                "centerline",zeros(0,2),"curvature",zeros(0,1), ...
                "position",[NaN;NaN],"velocity",[NaN;NaN], ...
                "acceleration",[NaN;NaN],"confidence",0,"state","invalid", ...
                "status","invalid","reason","没有可用于识别的事件。", ...
                "rawEventCount",0,"filteredEventCount",0, ...
                "maskPixelCount",0,"outlinePointCount",0, ...
                "centerlinePointCount",0,"windowReady",false);
        end
        function value = scalarField(~,packet,field,defaultValue)
            value = defaultValue;
            if isfield(packet,field)
                candidate = packet.(field);
                if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate)
                    value = max(0,round(double(candidate)));
                end
            end
        end
    end
end
