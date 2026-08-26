function tests = testLiveViewerFacade
tests = functiontests(localfunctions);
end

function testSelectsWorkbenchAdapterByDefault(testCase)
viewer = ui.LiveViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>
verifyEqual(testCase,string(viewer.AdapterName),"workbench");
end

function testFacadeShowsAndClearsROI(testCase)
viewer = ui.LiveViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.showROI([20 30 40 50]);
viewer.clearROI();

roi = findall(ancestor(viewer.getImageHandle(),"figure"), ...
    "Type","rectangle","Tag","DVSenseROI");
verifyEqual(testCase,string(roi.Visible),"off");
end

function cfg = localConfig()
cfg.display.enabled = true;
cfg.display.visible = false;
cfg.display.scale = 0.1;
cfg.display.refreshHz = 25;
cfg.source.resolution = [72 128];
cfg.source.windowUs = uint64(20000);
cfg.roi.enabled = false;
cfg.roi.rectangle = [1 1 128 72];
cfg.tracking.minimumEvents = 20;
cfg.tracking.processNoise = 30;
cfg.tracking.measurementNoise = 8;
cfg.recording.saveTracking = true;
cfg.recording.rawDirectory = tempdir;
end

