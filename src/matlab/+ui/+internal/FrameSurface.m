classdef FrameSurface < handle
    properties (SetAccess = private)
        ImageAxes
        ImageHandle
        TrackBox
        TrackPoint
        OutlineLine
        OutlineMarkers
        CenterlineLine
        RoiBox
    end
    properties (Access = private)
        Height (1,1) double
        Width (1,1) double
        SourceHeight (1,1) double
        SourceWidth (1,1) double
        Scale (1,1) double = 1
        OverlayVisible (1,1) logical = true
        ParentFigure
        SelectionStart double = zeros(0,2)
        SelectionCallback = []
        CancelCallback = []
        PreviousButtonDownCallback = []
        PreviousButtonMotionCallback = []
        PreviousButtonUpCallback = []
        PreviousKeyPressCallback = []
    end

    methods
        function obj = FrameSurface(parent,cfg)
            arguments
                parent (1,1) matlab.ui.container.Container
                cfg (1,1) struct
            end
            resolution = double(cfg.resolution);
            scale = 1;
            if isfield(cfg,"scale")
                scale = max(0.1,min(1,double(cfg.scale)));
            end
            obj.Scale = scale;
            obj.SourceHeight = max(1,round(resolution(1)));
            obj.SourceWidth = max(1,round(resolution(2)));
            obj.Height = max(1,round(resolution(1)*scale));
            obj.Width = max(1,round(resolution(2)*scale));

            grid = uigridlayout(parent,[1 1]);
            grid.Padding = [0 0 0 0];
            grid.BackgroundColor = [0.42 0.42 0.42];
            obj.ImageAxes = uiaxes(grid);
            obj.ImageAxes.XTick = [];
            obj.ImageAxes.YTick = [];
            obj.ImageAxes.Toolbar.Visible = "off";
            obj.ImageAxes.InteractionOptions = [];
            obj.ImageAxes.Color = [112 112 112]/255;
            obj.ImageHandle = image(obj.ImageAxes, ...
                ones(obj.Height,obj.Width,"uint8"));
            obj.ImageHandle.CDataMapping = "scaled";
            obj.ImageHandle.Interpolation = "nearest";
            colormap(obj.ImageAxes,[112 112 112;255 255 255;0 0 0]/255);
            obj.ImageAxes.CLim = [1 3];
            obj.ImageAxes.XLim = [1 obj.Width];
            obj.ImageAxes.YLim = [1 obj.Height];
            obj.ImageAxes.YDir = "reverse";
            obj.ImageAxes.DataAspectRatioMode = "auto";
            obj.ImageAxes.PlotBoxAspectRatioMode = "auto";
            hold(obj.ImageAxes,"on");
            obj.TrackBox = rectangle(obj.ImageAxes,"Position",[1 1 1 1], ...
                "EdgeColor",[0.39 0.78 0.58],"LineWidth",1.5, ...
                "Visible","off");
            obj.TrackPoint = plot(obj.ImageAxes,NaN,NaN,"+", ...
                "Color",[0.39 0.78 0.58],"MarkerSize",10, ...
                "LineWidth",1.5,"Visible","off");
            obj.OutlineLine = plot(obj.ImageAxes,NaN,NaN,"-", ...
                "Color",[0.05 0.85 0.22],"LineWidth",2.5, ...
                "Visible","off","Tag","DVSenseOutline");
            obj.OutlineMarkers = plot(obj.ImageAxes,NaN,NaN,"o", ...
                "Color",[0.39 0.78 0.58],"MarkerSize",3, ...
                "LineWidth",0.75,"MarkerFaceColor",[0.39 0.78 0.58], ...
                "Visible","off","Tag","DVSenseOutlineMarkers");
            obj.CenterlineLine = plot(obj.ImageAxes,NaN,NaN,"-", ...
                "Color",[0.03 0.36 0.51],"LineWidth",1.5, ...
                "Visible","off","Tag","DVSenseCenterline");
            obj.RoiBox = rectangle(obj.ImageAxes,"Position",[1 1 1 1], ...
                "EdgeColor",[0.97 0.72 0.22],"LineWidth",1.5, ...
                "LineStyle","--","Visible","off","Tag","DVSenseROI");
            obj.ParentFigure = ancestor(obj.ImageAxes,"figure");
        end

        function update(obj,frame,track)
            if ~isgraphics(obj.ImageHandle)
                return
            end
            obj.ImageHandle.CData = frame;
            if ~obj.OverlayVisible || ~isstruct(track) || ...
                    ~isfield(track,"valid") || ~track.valid
                obj.hideOverlays();
                return
            end
            if isfield(track,"boundingBox") && all(isfinite(track.boundingBox))
                box = double(track.boundingBox);
                box(1:2) = (box(1:2)-1)*obj.Scale+1;
                box(3:4) = box(3:4)*obj.Scale;
                obj.TrackBox.Position = box;
                obj.TrackBox.Visible = "on";
            end
            if isfield(track,"position") && all(isfinite(track.position))
                point = (double(track.position)-1)*obj.Scale+1;
                obj.TrackPoint.XData = point(1);
                obj.TrackPoint.YData = point(2);
                obj.TrackPoint.Visible = "on";
            end
        end

        function setAnalysis(obj,riserResult)
            if ~isstruct(riserResult)
                obj.clearAnalysis();
                return
            end
            outlineData = zeros(0,2);
            if isfield(riserResult,"outlines") && ~isempty(riserResult.outlines)
                outlineData = riserResult.outlines;
            elseif isfield(riserResult,"outline") && ~isempty(riserResult.outline)
                outlineData = riserResult.outline;
            end
            hasOutline = ~isempty(outlineData);
            hasCenterline = isfield(riserResult,"centerline") && ...
                ~isempty(riserResult.centerline);
            if ~hasOutline && ~hasCenterline
                obj.clearAnalysis();
                return
            end
            if hasOutline
                outline = (double(outlineData)-1)*obj.Scale+1;
                obj.OutlineLine.XData = outline(:,1);
                obj.OutlineLine.YData = outline(:,2);
                obj.OutlineLine.Visible = "on";
                obj.OutlineMarkers.XData = outline(:,1);
                obj.OutlineMarkers.YData = outline(:,2);
                obj.OutlineMarkers.Visible = "on";
            else
                obj.clearOutline();
            end
            if hasCenterline
                centerline = (double(riserResult.centerline)-1)*obj.Scale+1;
                obj.CenterlineLine.XData = centerline(:,1);
                obj.CenterlineLine.YData = centerline(:,2);
                obj.CenterlineLine.Visible = "on";
            else
                obj.clearCenterline();
            end
        end

        function setOverlayVisible(obj,value)
            obj.OverlayVisible = logical(value);
            if ~obj.OverlayVisible
                obj.hideOverlays();
                obj.clearAnalysis();
            end
        end

        function setROI(obj,rectangle)
            position = double(rectangle);
            if ~isequal(size(position),[1 4]) || any(~isfinite(position)) || ...
                    any(position(3:4) <= 0)
                error("DVSense:InvalidROI","ROI必须是有效的[x y width height]。");
            end
            position(1:2) = (position(1:2)-1)*obj.Scale+1;
            position(3:4) = position(3:4)*obj.Scale;
            obj.RoiBox.Position = position;
            obj.RoiBox.Visible = "on";
        end

        function clearROI(obj)
            obj.cancelROISelection(false);
            if isgraphics(obj.RoiBox)
                obj.RoiBox.Visible = "off";
            end
        end

        function beginROISelection(obj,onSelection,onCancel)
            arguments
                obj
                onSelection (1,1) function_handle
                onCancel = []
            end
            obj.cancelROISelection(false);
            if isempty(obj.ParentFigure) || ~isvalid(obj.ParentFigure)
                return
            end
            obj.SelectionCallback = onSelection;
            obj.CancelCallback = onCancel;
            obj.PreviousButtonDownCallback = obj.ParentFigure.WindowButtonDownFcn;
            obj.PreviousButtonMotionCallback = obj.ParentFigure.WindowButtonMotionFcn;
            obj.PreviousButtonUpCallback = obj.ParentFigure.WindowButtonUpFcn;
            obj.PreviousKeyPressCallback = obj.ParentFigure.WindowKeyPressFcn;
            obj.ParentFigure.WindowButtonDownFcn = @(~,~)obj.startROISelection();
            obj.ParentFigure.WindowButtonMotionFcn = @(~,~)obj.updateROISelection();
            obj.ParentFigure.WindowButtonUpFcn = @(~,~)obj.completeROISelection();
            obj.ParentFigure.WindowKeyPressFcn = @(~,event)obj.handleKeyPress(event);
            obj.ParentFigure.Pointer = "crosshair";
        end

        function finishROISelection(obj,startPoint,endPoint)
            if isempty(obj.SelectionCallback)
                return
            end
            rectangle = ui.internal.displayPointsToROI(startPoint,endPoint, ...
                obj.Scale,[obj.SourceHeight obj.SourceWidth]);
            callback = obj.SelectionCallback;
            obj.endROISelection();
            obj.setROI(rectangle);
            callback(rectangle);
        end

        function reset(obj)
            if ~isgraphics(obj.ImageHandle)
                return
            end
            obj.ImageHandle.CData = ones(obj.Height,obj.Width,"uint8");
            obj.hideOverlays();
            obj.clearAnalysis();
        end

        function handle = getImageHandle(obj)
            handle = obj.ImageHandle;
        end

        function delete(obj)
            obj.cancelROISelection(false);
            handles = [obj.ImageAxes obj.TrackBox obj.TrackPoint ...
                obj.OutlineLine obj.OutlineMarkers obj.CenterlineLine obj.RoiBox];
            handles = handles(isgraphics(handles));
            if ~isempty(handles)
                delete(handles);
            end
        end
    end

    methods (Access = private)
        function startROISelection(obj)
            point = obj.currentDisplayPoint();
            if isempty(point)
                return
            end
            obj.SelectionStart = point;
            obj.RoiBox.Position = [point 0 0];
            obj.RoiBox.Visible = "on";
        end

        function updateROISelection(obj)
            if isempty(obj.SelectionStart)
                return
            end
            point = obj.currentDisplayPoint();
            if isempty(point)
                return
            end
            obj.RoiBox.Position = localDisplayPosition(obj.SelectionStart,point);
        end

        function completeROISelection(obj)
            if isempty(obj.SelectionStart)
                return
            end
            startPoint = obj.SelectionStart;
            point = obj.currentDisplayPoint();
            if isempty(point)
                obj.cancelROISelection(true);
                return
            end
            obj.finishROISelection(startPoint,point);
        end

        function handleKeyPress(obj,event)
            if isprop(event,"Key") && string(event.Key) == "escape"
                obj.cancelROISelection(true);
            end
        end

        function cancelROISelection(obj,notify)
            if nargin < 2
                notify = false;
            end
            callback = obj.CancelCallback;
            wasSelecting = ~isempty(obj.SelectionCallback);
            obj.endROISelection();
            if notify && wasSelecting && ~isempty(callback)
                callback();
            end
        end

        function endROISelection(obj)
            obj.SelectionStart = zeros(0,2);
            if ~isempty(obj.ParentFigure) && isvalid(obj.ParentFigure)
                obj.ParentFigure.WindowButtonDownFcn = obj.PreviousButtonDownCallback;
                obj.ParentFigure.WindowButtonMotionFcn = obj.PreviousButtonMotionCallback;
                obj.ParentFigure.WindowButtonUpFcn = obj.PreviousButtonUpCallback;
                obj.ParentFigure.WindowKeyPressFcn = obj.PreviousKeyPressCallback;
                obj.ParentFigure.Pointer = "arrow";
            end
            obj.SelectionCallback = [];
            obj.CancelCallback = [];
            obj.PreviousButtonDownCallback = [];
            obj.PreviousButtonMotionCallback = [];
            obj.PreviousButtonUpCallback = [];
            obj.PreviousKeyPressCallback = [];
        end

        function point = currentDisplayPoint(obj)
            point = zeros(0,2);
            if isempty(obj.ParentFigure) || ~isvalid(obj.ParentFigure)
                return
            end
            values = double(obj.ImageAxes.CurrentPoint);
            candidate = values(1,1:2);
            if any(~isfinite(candidate)) || candidate(1) < 1 || ...
                    candidate(1) > obj.Width || candidate(2) < 1 || ...
                    candidate(2) > obj.Height
                return
            end
            point = candidate;
        end

        function hideOverlays(obj)
            if isgraphics(obj.TrackBox), obj.TrackBox.Visible = "off"; end
            if isgraphics(obj.TrackPoint), obj.TrackPoint.Visible = "off"; end
        end

        function clearAnalysis(obj)
            obj.clearOutline();
            obj.clearCenterline();
        end

        function clearOutline(obj)
            if isgraphics(obj.OutlineLine)
                obj.OutlineLine.XData = [];
                obj.OutlineLine.YData = [];
                obj.OutlineLine.Visible = "off";
            end
            if isgraphics(obj.OutlineMarkers)
                obj.OutlineMarkers.XData = [];
                obj.OutlineMarkers.YData = [];
                obj.OutlineMarkers.Visible = "off";
            end
        end

        function clearCenterline(obj)
            if isgraphics(obj.CenterlineLine)
                obj.CenterlineLine.XData = [];
                obj.CenterlineLine.YData = [];
                obj.CenterlineLine.Visible = "off";
            end
        end
    end
end

function position = localDisplayPosition(startPoint,endPoint)
left = min(startPoint(1),endPoint(1));
top = min(startPoint(2),endPoint(2));
position = [left top abs(endPoint-startPoint)];
end
