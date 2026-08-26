function tests=testWorkbenchViewerContract
tests=functiontests(localfunctions);
end

function testViewerExposesWorkbenchAdapterName(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

verifyEqual(testCase,string(viewer.AdapterName),"workbench");
end

function testAnalysisResultUsesDedicatedOverlayHandles(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

result=struct( ...
    "valid",true, ...
    "outline",[10 10; 20 10; 20 30; 10 30], ...
    "centerline",[15 10; 15 20; 15 30], ...
    "curvature",[0.1;0.2;0.1], ...
    "confidence",0.92, ...
    "state","tracking");
track=localTrack;
backend=struct("requested","matlab-gpu","executed","cpu", ...
    "fallback",true,"reason","test");

viewer.setAnalysisResult(result,track,backend);
drawnow;

outline=findall(groot,"Type","line","Tag","DVSenseOutline");
centerline=findall(groot,"Type","line","Tag","DVSenseCenterline");
verifyNumElements(testCase,outline,1);
verifyNumElements(testCase,centerline,1);
verifyEqual(testCase,outline.XData,[1.9 2.9 2.9 1.9],"AbsTol",1e-12);
verifyEqual(testCase,centerline.XData,[2.4 2.4 2.4],"AbsTol",1e-12);
end

function testRecognitionStatusIsPublishedToLiveSurface(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.setRecognitionStatus(struct( ...
    "status","centerline-empty", ...
    "reason","已分割出目标，但未提取到中心线。", ...
    "rawEventCount",225, ...
    "filteredEventCount",181, ...
    "maskPixelCount",1042, ...
    "outlinePointCount",78, ...
    "centerlinePointCount",0, ...
    "windowReady",true, ...
    "confidence",0.62));
drawnow;

liveHtml = findall(groot,"Type","uihtml");
liveHtml = liveHtml(arrayfun(@(h)contains(string(h.HTMLSource),"live.html"),liveHtml));
verifyNumElements(testCase,liveHtml,1);
data = liveHtml.Data;
verifyEqual(testCase,string(data.analysisStatus),"centerline-empty");
verifyEqual(testCase,string(data.analysisReason),"已分割出目标，但未提取到中心线。");
verifyEqual(testCase,data.analysisWindowReady,true);
end

function testDisplayAccumulationUpdateIsPublishedToSettingsSurface(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.setDisplayAccumulationUs(25000);
drawnow;

settingsHtml = findall(groot,"Type","uihtml");
settingsHtml = settingsHtml(arrayfun(@(h)contains(string(h.HTMLSource),"settings.html"),settingsHtml));
verifyNumElements(testCase,settingsHtml,1);
data = settingsHtml.Data;
verifyEqual(testCase,data.displayAccumulationUs,25000);
end

function testAnalysisResultCanBeCleared(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.setAnalysisResult(struct("valid",false),localTrack, ...
    struct("requested","cpu","executed","cpu","fallback",false,"reason",""));
drawnow;

outline=findall(groot,"Type","line","Tag","DVSenseOutline");
centerline=findall(groot,"Type","line","Tag","DVSenseCenterline");
verifyNumElements(testCase,outline,1);
verifyNumElements(testCase,centerline,1);
verifyEmpty(testCase,outline.XData);
verifyEmpty(testCase,centerline.XData);
end

function testAnalysisResultPublishesDiagnostics(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

result=struct( ...
    "valid",false, ...
    "timestampUs",uint64(1), ...
    "mask",false(72,128), ...
    "outline",[10 10; 20 10; 20 30; 10 30], ...
    "centerline",zeros(0,2), ...
    "curvature",zeros(0,1), ...
    "position",[NaN;NaN], ...
    "velocity",[NaN;NaN], ...
    "acceleration",[NaN;NaN], ...
    "confidence",0.31, ...
    "state","invalid", ...
    "status","centerline-empty", ...
    "reason","已分割出目标，但未提取到中心线。", ...
    "rawEventCount",225, ...
    "filteredEventCount",181, ...
    "maskPixelCount",1042, ...
    "outlinePointCount",78, ...
    "centerlinePointCount",0, ...
    "windowReady",true);
track=localTrack;
backend=struct("requested","matlab-gpu","executed","cpu", ...
    "fallback",true,"reason","test");

viewer.setAnalysisResult(result,track,backend);
drawnow;

analysisHtml = findall(groot,"Type","uihtml");
analysisHtml = analysisHtml(arrayfun(@(h)contains(string(h.HTMLSource),"analysis.html"),analysisHtml));
verifyNumElements(testCase,analysisHtml,1);
data = analysisHtml.Data;
verifyEqual(testCase,string(data.status),"centerline-empty");
verifyEqual(testCase,string(data.reason),"已分割出目标，但未提取到中心线。");
verifyEqual(testCase,data.maskPixelCount,1042);
verifyEqual(testCase,data.outlinePointCount,78);
verifyEqual(testCase,data.centerlinePointCount,0);
end

function testAnalysisResultPublishesLiveDiagnostics(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

result=struct( ...
    "valid",true, ...
    "outline",[10 10; 20 10; 20 30; 10 30], ...
    "centerline",[15 10; 15 20; 15 30], ...
    "curvature",[0;0;0], ...
    "confidence",0.8, ...
    "state","stable", ...
    "status","valid", ...
    "reason","轮廓与中心线已识别。", ...
    "rawEventCount",240, ...
    "filteredEventCount",190, ...
    "maskPixelCount",1030, ...
    "outlinePointCount",88, ...
    "centerlinePointCount",55, ...
    "windowReady",true);

viewer.setAnalysisResult(result,localTrack,struct());
drawnow;

liveHtml = findall(groot,"Type","uihtml");
liveHtml = liveHtml(arrayfun(@(h)contains(string(h.HTMLSource),"live.html"),liveHtml));
verifyNumElements(testCase,liveHtml,1);
data = liveHtml.Data;
verifyEqual(testCase,data.maskPixelCount,1030);
verifyEqual(testCase,data.outlinePointCount,88);
verifyEqual(testCase,data.centerlinePointCount,55);
end

function testUpdatePublishesTimestampAndBandwidth(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

frame = ones(72,128,"uint8");
track = localTrack;
stats = struct( ...
    "timestampUs",uint64(12603147), ...
    "eventCount",937412, ...
    "eventRate",9.3e6, ...
    "recognitionStatus","valid", ...
    "recognitionReason","轮廓与中心线已识别。");
viewer.update(frame,track,stats);
drawnow;

liveHtml = findall(groot,"Type","uihtml");
liveHtml = liveHtml(arrayfun(@(h)contains(string(h.HTMLSource),"live.html"),liveHtml));
verifyNumElements(testCase,liveHtml,1);
data = liveHtml.Data;
verifyEqual(testCase,string(data.timestamp),"00:00:12:603147");
verifyEqual(testCase,string(data.bandwidth),"9.3 Mev/s");
end

function testResetProcessingViewClearsOverlaysAndCounters(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

result=struct("valid",true,"outline",[1 1;2 2], ...
    "centerline",[1 1;2 2]);
viewer.setAnalysisResult(result,localTrack,struct());
viewer.resetProcessingView();
drawnow;

outline=findall(groot,"Type","line","Tag","DVSenseOutline");
centerline=findall(groot,"Type","line","Tag","DVSenseCenterline");
verifyEmpty(testCase,outline.XData);
verifyEmpty(testCase,centerline.XData);
imageHandle=viewer.getImageHandle();
verifyEqual(testCase,imageHandle.CData(1,1),uint8(1));
end

function testCommandErrorIsVisibleWithoutClosingViewer(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.setCommandError(struct("type","setToolParameter"),"synthetic");
drawnow;

verifyTrue(testCase,viewer.isRunning());
end

function testWorkbenchViewerContainsLowRateHtmlStatusSurface(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.LiveViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

verifyEqual(testCase,string(viewer.AdapterName),"workbench");
imageHandle=viewer.getImageHandle();
verifyTrue(testCase,isgraphics(imageHandle));
verifyEqual(testCase,string(imageHandle.CDataMapping),"scaled");
verifyEqual(testCase,imageHandle.Parent.CLim,[1 3]);
end

function testWorkbenchViewerClassIsProductionAdapter(testCase)
close(findall(groot,"Type","figure"));
viewer=ui.WorkbenchViewer(localConfig);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>

verifyEqual(testCase,string(viewer.AdapterName),"workbench");
verifyEqual(testCase,string(class(viewer)),"ui.WorkbenchViewer");
end

function cfg=localConfig
cfg.display.enabled=true;
cfg.display.scale=0.1;
cfg.display.accumulationUs=5000;
cfg.source.resolution=[72 128];
cfg.source.windowUs=uint64(20000);
cfg.roi.enabled=false;
cfg.roi.mode="software";
cfg.roi.rectangle=[1 1 128 72];
cfg.tracking.minimumEvents=20;
cfg.tracking.processNoise=30;
cfg.tracking.measurementNoise=8;
cfg.recording.saveTracking=true;
cfg.recording.rawDirectory=tempdir;
end

function track=localTrack
track=struct("valid",true,"timestampUs",uint64(1), ...
    "position",[15;20],"velocity",[0;0], ...
    "boundingBox",[10 10 11 21],"confidence",0.9);
end

