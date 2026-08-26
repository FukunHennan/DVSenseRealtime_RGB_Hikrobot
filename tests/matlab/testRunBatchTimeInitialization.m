function tests = testRunBatchTimeInitialization
tests = functiontests(localfunctions);
end

function testBatchTimeIsInitializedBeforeInitialConnection(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
source = char(fileread(fullfile(projectRoot,"src","matlab","+app","run.m")));

batchInitialization = strfind(source,"batchTimeUs = double(cfg.source.windowUs);");
initialConnection = strfind(source,"selectedSerial=connectWithDecision();");

verifyNotEmpty(testCase,batchInitialization);
verifyNotEmpty(testCase,initialConnection);
verifyLessThan(testCase,batchInitialization(1),initialConnection(1), ...
    "batchTimeUs must exist before the first nested connection call.");
end

