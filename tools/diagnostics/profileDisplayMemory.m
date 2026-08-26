function stats = profileDisplayMemory(durationSeconds)
arguments
    durationSeconds (1,1) double {mustBePositive} = 8
end

projectRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
run(fullfile(projectRoot,"tools","dev","setupPath.m"));

cfg.source.resolution=[720 1280];
cfg.source.windowUs=uint64(1000);
cfg.display.enabled=true;
cfg.display.scale=1;
cfg.display.accumulationUs=5000;
cfg.display.refreshHz=25;
cfg.roi.enabled=false;
cfg.roi.mode="hardware";
cfg.roi.rectangle=[1 1 1280 720];
cfg.tracking.minimumEvents=20;
cfg.tracking.processNoise=30;
cfg.tracking.measurementNoise=8;
cfg.tracking.initialCovariance=100;
cfg.source.eventsPerWindow=2500;
cfg.compute.countClamp=8;
cfg.processing.activityFilterEnabled=true;
cfg.processing.minimumNeighborSupport=1;
cfg.recording.saveTracking=true;
cfg.recording.rawDirectory=fullfile(projectRoot,"artifacts","output","recordings");

rng(1);
eventCount=100000;
packet.x=uint16(randi(cfg.source.resolution(2),eventCount,1));
packet.y=uint16(randi(cfg.source.resolution(1),eventCount,1));
packet.polarity=rand(eventCount,1)>=0.5;
packet.timestamp=uint64(linspace(1,double(cfg.display.accumulationUs),eventCount)).';
packet.resolution=cfg.source.resolution;
packet.timeEndUs=max(packet.timestamp);

track=struct("valid",false,"position",[NaN;NaN], ...
    "boundingBox",[NaN NaN NaN NaN],"velocity",[NaN;NaN], ...
    "timestampUs",uint64(0),"confidence",0);
statsForViewer=struct("eventCount",eventCount,"latencyUs",0, ...
    "backend","cpu","deadlineMiss",false);

backend=analysis.CpuMeasurementBackend;
viewer=ui.LiveViewer(cfg);
cleanup=onCleanup(@()delete(viewer)); %#ok<NASGU>
drawnow;

memoryStart=memory;
peakMatlabBytes=memoryStart.MemUsedMATLAB;
frameCount=0;
renderSeconds=0;
updateSeconds=0;
nextMemorySample=1;
started=tic;
while toc(started)<durationSeconds && viewer.isRunning()
    operationStarted=tic;
    frame=backend.render(packet,cfg);
    renderSeconds=renderSeconds+toc(operationStarted);
    operationStarted=tic;
    viewer.update(frame,track,statsForViewer);
    updateSeconds=updateSeconds+toc(operationStarted);
    frameCount=frameCount+1;
    elapsed=toc(started);
    if elapsed>=nextMemorySample
        currentMemory=memory;
        peakMatlabBytes=max(peakMatlabBytes,currentMemory.MemUsedMATLAB);
        nextMemorySample=nextMemorySample+1;
    end
    pause(max(0,frameCount/cfg.display.refreshHz-toc(started)));
end
memoryEnd=memory;

stats=struct( ...
    "frameCount",frameCount, ...
    "frameSize",size(frame), ...
    "frameClass",class(frame), ...
    "startMB",memoryStart.MemUsedMATLAB/1024^2, ...
    "endMB",memoryEnd.MemUsedMATLAB/1024^2, ...
    "peakMB",peakMatlabBytes/1024^2, ...
    "meanRenderMs",renderSeconds/max(frameCount,1)*1000, ...
    "meanUpdateMs",updateSeconds/max(frameCount,1)*1000);
fprintf("display_profile frames=%d size=%dx%d class=%s render=%.2fms " + ...
    "update=%.2fms start=%.1fMB end=%.1fMB peak=%.1fMB\n", ...
    stats.frameCount,stats.frameSize(1),stats.frameSize(2),stats.frameClass, ...
    stats.meanRenderMs,stats.meanUpdateMs, ...
    stats.startMB,stats.endMB,stats.peakMB);
end
