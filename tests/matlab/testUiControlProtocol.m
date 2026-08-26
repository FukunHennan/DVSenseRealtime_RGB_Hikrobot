function tests = testUiControlProtocol
tests = functiontests(localfunctions);
end

function testMapsValidatedToolParameterEvent(testCase)
parameter = struct("tool","Biases","name","bias_diff","type","INT", ...
    "min","-25","max","23","unit","%","options",strings(0), ...
    "current","-15","defaultValue","-15","details","");
event = struct("version",1,"sequence",7, ...
    "type","setToolParameter", ...
    "payload",struct("index",1,"tool","Biases", ...
    "name","bias_diff","value",5));

command = ui.internal.mapControlEvent(event,parameter);

verifyEqual(testCase,string(command.type),"setToolParameter");
verifyEqual(testCase,command.value,5);
verifyEqual(testCase,command.index,1);
end

function testRejectsUnknownProtocolVersion(testCase)
event = struct("version",2,"sequence",1,"type","stop","payload",struct);
verifyError(testCase,@()ui.internal.mapControlEvent(event,struct([])), ...
    "DVSense:UIProtocolVersion");
end

function testMapsDisplayAccumulationEvent(testCase)
event = struct("version",1,"sequence",11, ...
    "type","setDisplayAccumulationUs", ...
    "payload",struct("value",40000));

command = ui.internal.mapControlEvent(event,struct([]));

verifyEqual(testCase,string(command.type),"setDisplayAccumulationUs");
verifyEqual(testCase,command.value,40000);
verifyEqual(testCase,command.sequence,11);
end

function testRejectsDisplayAccumulationOutsideSupportedRange(testCase)
event = struct("version",1,"sequence",12, ...
    "type","setDisplayAccumulationUs", ...
    "payload",struct("value",0));

verifyError(testCase,@()ui.internal.mapControlEvent(event,struct([])), ...
    "DVSense:InvalidDisplayAccumulation");
end

function testMapsROISelectionCommands(testCase)
beginEvent = struct("version",1,"sequence",13, ...
    "type","beginROISelection","payload",struct);
clearEvent = struct("version",1,"sequence",14, ...
    "type","clearROI","payload",struct);

beginCommand = ui.internal.mapControlEvent(beginEvent,struct([]));
clearCommand = ui.internal.mapControlEvent(clearEvent,struct([]));

verifyEqual(testCase,string(beginCommand.type),"beginROISelection");
verifyEqual(testCase,string(clearCommand.type),"clearROI");
end

function testNormalizeROIOrdersAndClampsRectangle(testCase)
rectangle = ui.internal.normalizeROI([90 70 -60 -100],[128 96]);

verifyEqual(testCase,rectangle,[30 1 61 70]);
end

function testDisplayDragMapsBackToFullResolutionROI(testCase)
rectangle = ui.internal.displayPointsToROI([10 20],[30 40],0.5,[720 1280]);

verifyEqual(testCase,rectangle,[19 39 41 41]);
end

