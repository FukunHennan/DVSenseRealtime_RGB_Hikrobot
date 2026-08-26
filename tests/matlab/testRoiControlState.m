function tests = testRoiControlState
tests = functiontests(localfunctions);
end

function testSetROIEnablesAndClampsSoftwareSelection(testCase)
cfg = localConfig();
command = struct("type","setROI","rectangle",[90 70 -60 -100]);

cfg = app.applyROICommand(cfg,command);

verifyTrue(testCase,cfg.roi.enabled);
verifyEqual(testCase,cfg.roi.rectangle,[30 1 61 70]);
end

function testClearROIRestoresFullSensorSelection(testCase)
cfg = localConfig();
cfg.roi.enabled = true;
cfg.roi.rectangle = [20 30 40 50];

cfg = app.applyROICommand(cfg,struct("type","clearROI"));

verifyFalse(testCase,cfg.roi.enabled);
verifyEqual(testCase,cfg.roi.rectangle,[1 1 128 96]);
end

function cfg = localConfig()
cfg.source.resolution = [96 128];
cfg.roi.enabled = false;
cfg.roi.mode = "software";
cfg.roi.rectangle = [1 1 128 96];
end

