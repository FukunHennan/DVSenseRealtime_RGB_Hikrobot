function tests = testFrameSurface
tests = functiontests(localfunctions);
end

function testReusesSingleImageHandle(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",0.5));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

first = surface.getImageHandle();
surface.update(ones(360,640,"uint8"),localTrack());
surface.update(3*ones(360,640,"uint8"),localTrack());

verifyTrue(testCase,isgraphics(first));
verifyEqual(testCase,surface.getImageHandle(),first);
verifyEqual(testCase,first.CData(1,1),uint8(3));
end

function testResetRestoresOfficialGrayFrame(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",1));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

surface.update(2*ones(720,1280,"uint8"),localTrack());
surface.reset();

verifyEqual(testCase,surface.getImageHandle().CData(1,1),uint8(1));
verifyEqual(testCase,string(surface.getImageHandle().CDataMapping),"scaled");
verifyEqual(testCase,surface.getImageHandle().Parent.CLim,[1 3]);
end

function testAnalysisOverlayShowsContourMarkers(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",0.5));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

result = struct("valid",true, ...
    "outline",[10 10; 11 10; 11 11; 10 11; 10 10], ...
    "centerline",[10 10; 10 11], ...
    "curvature",[0;0], ...
    "confidence",1, ...
    "state","stable");
surface.setAnalysis(result);

outline = findall(figureHandle,"Type","line","Tag","DVSenseOutline");
markers = findall(figureHandle,"Type","line","Tag","DVSenseOutlineMarkers");
verifyNumElements(testCase,outline,1);
verifyNumElements(testCase,markers,1);
verifyEqual(testCase,outline.XData,markers.XData);
verifyEqual(testCase,outline.YData,markers.YData);
end

function testPartialContourClearsCenterline(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",0.5));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

result = struct("valid",false, ...
    "outline",[10 10; 11 10; 11 11; 10 11; 10 10], ...
    "centerline",zeros(0,2), ...
    "curvature",zeros(0,1), ...
    "confidence",0.2, ...
    "state","invalid");
surface.setAnalysis(result);

outline = findall(figureHandle,"Type","line","Tag","DVSenseOutline");
markers = findall(figureHandle,"Type","line","Tag","DVSenseOutlineMarkers");
centerline = findall(figureHandle,"Type","line","Tag","DVSenseCenterline");
verifyNumElements(testCase,outline,1);
verifyNumElements(testCase,markers,1);
verifyNotEmpty(testCase,outline.XData);
verifyEmpty(testCase,centerline.XData);
end

function testContourOverlayUsesProminentGreenLine(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",0.5));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

result = struct("valid",false, ...
    "outline",[40 40; 80 40; 80 90; 40 90; 40 40], ...
    "centerline",zeros(0,2), ...
    "curvature",zeros(0,1), ...
    "confidence",0.5, ...
    "state","outline-only");
surface.setAnalysis(result);
surface.update(ones(360,640,"uint8"),localTrack());

outline = findall(figureHandle,"Type","line","Tag","DVSenseOutline");
verifyNumElements(testCase,outline,1);
verifyEqual(testCase,string(outline.Visible),"on");
verifyGreaterThanOrEqual(testCase,outline.LineWidth,2.5);
verifyEqual(testCase,outline.Color,[0.05 0.85 0.22],"AbsTol",1e-12);
end

function testContourOverlayKeepsMultipleSegmentsVisible(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",0.5));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

result = struct("valid",true, ...
    "outline",[10 10; 11 10; 11 11; 10 11; 10 10], ...
    "outlines",[10 10; 11 10; 11 11; 10 11; 10 10; NaN NaN; ...
        40 40; 41 40; 41 41; 40 41; 40 40], ...
    "centerline",zeros(0,2), ...
    "curvature",zeros(0,1), ...
    "confidence",0.5, ...
    "state","outline-only");
surface.setAnalysis(result);

outline = findall(figureHandle,"Type","line","Tag","DVSenseOutline");
verifyNumElements(testCase,outline,1);
verifyGreaterThan(testCase,sum(isnan(outline.XData)),0);
verifyGreaterThan(testCase,sum(isnan(outline.YData)),0);
end

function testRoiRectangleUsesFullResolutionCoordinates(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",0.5));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

surface.setROI([20 30 40 50]);

roi = findall(figureHandle,"Type","rectangle","Tag","DVSenseROI");
verifyNumElements(testCase,roi,1);
verifyEqual(testCase,roi.Position,[10.5 15.5 20 25],"AbsTol",1e-12);
verifyEqual(testCase,string(roi.Visible),"on");
end

function testFinishedSelectionReportsNormalizedSourceROI(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",0.5));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>
selected = [];

surface.beginROISelection(@receiveSelection);
surface.finishROISelection([10 20],[30 40]);

verifyEqual(testCase,selected,[19 39 41 41]);

    function receiveSelection(rectangle)
        selected = rectangle;
    end
end

function testClearROIHidesRectangle(testCase)
figureHandle = uifigure("Visible","off");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
surface = ui.internal.FrameSurface(figureHandle, ...
    struct("resolution",[720 1280],"scale",1));
surfaceCleanup = onCleanup(@()deleteIfValid(surface)); %#ok<NASGU>

surface.setROI([20 30 40 50]);
surface.clearROI();

roi = findall(figureHandle,"Type","rectangle","Tag","DVSenseROI");
verifyNumElements(testCase,roi,1);
verifyEqual(testCase,string(roi.Visible),"off");
end

function track = localTrack()
track = struct("valid",false,"boundingBox",[NaN NaN NaN NaN], ...
    "position",[NaN;NaN]);
end

function deleteIfValid(value)
if ~isempty(value) && isvalid(value)
    delete(value);
end
end

