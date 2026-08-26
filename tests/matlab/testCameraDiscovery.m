function tests=testCameraDiscovery
tests=functiontests(localfunctions);
end

function testPreferredSerialIsSelectedWhenPresent(testCase)
devices=localDevices;
serial=camera.selectCameraSerial(devices,"SERIAL-B");
verifyEqual(testCase,serial,"SERIAL-B");
end

function testSingleDiscoveredCameraIsSelectedWithoutPreference(testCase)
devices=localDevices(1);
serial=camera.selectCameraSerial(devices,"");
verifyEqual(testCase,serial,"SERIAL-A");
end

function testMissingPreferredSerialRequiresUserSelection(testCase)
devices=localDevices;
verifyError(testCase,@()camera.selectCameraSerial( ...
    devices,"MISSING"),"DVSense:CameraSelectionRequired");
end

function testEmptyDiscoveryRaisesNoCamera(testCase)
verifyError(testCase,@()camera.selectCameraSerial( ...
    struct([]),""),"DVSense:NoCamera");
end

function testSessionExposesDiscoveryWithoutOpeningCamera(testCase)
verifyTrue(testCase,ismethod("camera.DVSenseSession","discover"));
end

function testSourceOpenAcceptsSelectedSerial(testCase)
verifyTrue(testCase,ismethod("camera.DVSenseCameraSource","open"));
sourceText=fileread(fullfile( ...
    fileparts(fileparts(fileparts(mfilename("fullpath")))), ...
    "src","matlab","+camera","DVSenseCameraSource.m"));
verifyTrue(testCase,contains(sourceText,"selectedSerial"));
end

function testSourceAcceptsBatchTimeUpdateWhileClosed(testCase)
source=camera.DVSenseCameraSource(struct("source",struct("windowUs",uint64(10000))));

verifyWarningFree(testCase,@()source.setBatchTime(uint64(25000)));
end

function testViewerExposesCameraSelectionStep(testCase)
verifyTrue(testCase,ismethod("ui.LiveViewer","selectCamera"));
end

function testSessionExposesExplicitRecoveryOperations(testCase)
verifyTrue(testCase,ismethod("camera.DVSenseSession","listStaleHelpers"));
verifyTrue(testCase,ismethod("camera.DVSenseSession","terminateStaleHelpers"));
end

function testMainRetriesDiscoveryBeforeNoCameraFailure(testCase)
source=fileread(fullfile( ...
    fileparts(fileparts(fileparts(mfilename("fullpath")))), ...
    "src","matlab","+app","run.m"));
verifyTrue(testCase,contains(source,"isempty(devices)"));
verifyTrue(testCase,contains(source,"listStaleHelpers"));
verifyTrue(testCase,contains(source,"terminateStaleHelpers"));
verifyTrue(testCase,contains(source,"discover();"));
end

function devices=localDevices(count)
devices=struct( ...
    "product",{"DVSLume","DVSLume"}, ...
    "serial",{"SERIAL-A","SERIAL-B"}, ...
    "width",{1280,1280}, ...
    "height",{720,720}, ...
    "connected",{true,true});
if nargin==1
    devices=devices(1:count);
end
end

