function tests=testBridgeSourceSafety
tests=functiontests(localfunctions);
end

function testBridgeUsesBoundedPipeWaitAndChecksHelperExit(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
source=fileread(fullfile(root,"src","native","bridge","dvsense_bridge.cpp"));

verifySubstring(testCase,source,"PeekNamedPipe");
verifySubstring(testCase,source,"WaitForSingleObject(childProcess");
verifySubstring(testCase,source,"DVSENSE_RESPONSE_TIMEOUT_MS");
verifySubstring(testCase,source,"helper response timed out");
end

function testBridgeRejectsUnboundedResponsePayload(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
source=fileread(fullfile(root,"src","native","bridge","dvsense_bridge.cpp"));

verifySubstring(testCase,source,"MAX_RESPONSE_BYTES");
verifySubstring(testCase,source,"Helper response exceeds");
end

function testBridgeExposesIndependentCameraDiscovery(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
source=fileread(fullfile(root,"src","native","bridge","dvsense_bridge.cpp"));
header=fileread(fullfile(root,"src","native","bridge","dvsense_bridge.h"));

verifySubstring(testCase,source,"CMD_DISCOVER_CAMERAS");
verifySubstring(testCase,source,"dvsense_discover_cameras_json");
verifySubstring(testCase,header,"dvsense_discover_cameras_json");
verifySubstring(testCase,source,'launchHelper("",false)');
end

function testBridgeRecoveryIsExplicitAndPathScoped(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
source=fileread(fullfile(root,"src","native","bridge","dvsense_bridge.cpp"));
header=fileread(fullfile(root,"src","native","bridge","dvsense_bridge.h"));

verifySubstring(testCase,source,"dvsense_list_stale_helpers_json");
verifySubstring(testCase,source,"dvsense_terminate_stale_helpers");
verifySubstring(testCase,source,"QueryFullProcessImageNameW");
verifySubstring(testCase,source,"TerminateProcess");
verifySubstring(testCase,header,"dvsense_list_stale_helpers_json");
verifySubstring(testCase,header,"dvsense_terminate_stale_helpers");
end

function verifySubstring(testCase,actual,expected)
verifyTrue(testCase,contains(actual,expected));
end

