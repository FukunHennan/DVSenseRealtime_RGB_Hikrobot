function tests = testWorkbenchViewer
tests = functiontests(localfunctions);
end

function testBuildsOfficialWorkbenchWithoutCamera(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>

verifyTrue(testCase,viewer.isRunning());
verifyEqual(testCase,string(viewer.AdapterName),"workbench");
verifyTrue(testCase,isgraphics(viewer.getImageHandle()));
end

function testStopAndStartCommandsAreQueued(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.setRunningState(true);
viewer.queueTestEvent(struct("version",1,"sequence",1, ...
    "type","stop","payload",struct));
commands = viewer.consumeCommands();

verifyEqual(testCase,numel(commands),1);
verifyEqual(testCase,string(commands{1}.type),"stop");
end

function testParameterSliderProducesValidatedCommand(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>
parameter = struct("tool","Biases","name","bias_diff","type","INT", ...
    "min",-25,"max",23,"unit","%","options",strings(0), ...
    "current",-15,"defaultValue",-15,"details","");
viewer.setToolParameters(parameter);
viewer.queueTestEvent(struct("version",1,"sequence",2, ...
    "type","setToolParameter","payload",struct("index",1, ...
    "tool","Biases","name","bias_diff","value",5)));

commands = viewer.consumeCommands();

verifyEqual(testCase,numel(commands),1);
verifyEqual(testCase,commands{1}.value,5);
end

function testSdkBooleanTextBuildsScalarCheckboxValue(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>
parameter = struct("tool","ROI","name","enable","type","BOOL", ...
    "min",[],"max",[],"unit","","options",strings(0), ...
    "current","false","defaultValue","false","details","");

viewer.setToolParameters(parameter);

verifyTrue(testCase,viewer.isRunning());
end

function testSettingsReceivesDisplayAccumulationWindow(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.setToolParameters(struct([]));
drawnow;

settingsHtml = findall(groot,"Type","uihtml");
settingsHtml = settingsHtml(arrayfun(@(h)contains(string(h.HTMLSource),"settings.html"),settingsHtml));
verifyNumElements(testCase,settingsHtml,1);
data = settingsHtml.Data;
verifyEqual(testCase,data.displayAccumulationUs,5000);
end

function testDisplayAccumulationCommandIsQueued(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.queueTestEvent(struct("version",1,"sequence",12, ...
    "type","setDisplayAccumulationUs","payload",struct("value",40000)));
commands = viewer.consumeCommands();

verifyEqual(testCase,numel(commands),1);
verifyEqual(testCase,string(commands{1}.type),"setDisplayAccumulationUs");
verifyEqual(testCase,commands{1}.value,40000);
end

function testROISelectionEventEntersImageSelectionMode(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>

viewer.queueTestEvent(struct("version",1,"sequence",13, ...
    "type","beginROISelection","payload",struct));

figureHandle = ancestor(viewer.getImageHandle(),"figure");
verifyEqual(testCase,string(figureHandle.Pointer),"crosshair");
verifyEmpty(testCase,viewer.consumeCommands());
end

function testClearROIEventHidesRectangleAndQueuesCommand(testCase)
viewer = ui.WorkbenchViewer(localConfig());
cleanup = onCleanup(@()delete(viewer)); %#ok<NASGU>
viewer.showROI([20 30 40 50]);

viewer.queueTestEvent(struct("version",1,"sequence",14, ...
    "type","clearROI","payload",struct));

roi = findall(ancestor(viewer.getImageHandle(),"figure"), ...
    "Type","rectangle","Tag","DVSenseROI");
verifyEqual(testCase,string(roi.Visible),"off");
commands = viewer.consumeCommands();
verifyEqual(testCase,string(commands{1}.type),"clearROI");
end

function cfg = localConfig()
cfg.display.enabled = true;
cfg.display.accumulationUs = 5000;
cfg.display.scale = 0.5;
cfg.display.visible = false;
cfg.source.resolution = [720 1280];
cfg.roi.enabled = false;
cfg.roi.rectangle = [1 1 1280 720];
cfg.paths.defaultParameterFile = "";
end

