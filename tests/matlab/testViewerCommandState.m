function tests=testViewerCommandState
tests=functiontests(localfunctions);
end

function testStopCommandRequestsLoopExit(testCase)
commands={struct("type","stop")};
[stopRequested,accumulationUs]=app.readViewerCommandState(commands,5000);
verifyTrue(testCase,stopRequested);
verifyEqual(testCase,accumulationUs,5000);
end

function testDisplayAccumulationCommandUpdatesWindow(testCase)
commands={struct("type","setDisplayAccumulationUs","value",40000)};
[stopRequested,accumulationUs]=app.readViewerCommandState(commands,5000);
verifyFalse(testCase,stopRequested);
verifyEqual(testCase,accumulationUs,40000);
end

function testDisplayAccumulationIsClampedToSupportedRange(testCase)
commands={ ...
    struct("type","setDisplayAccumulationUs","value",0), ...
    struct("type","setDisplayAccumulationUs","value",200000)};
[~,accumulationUs]=app.readViewerCommandState(commands,5000);
verifyEqual(testCase,accumulationUs,100000);
end

function testStartCommandRequestsLoopResume(testCase)
commands={struct("type","start")};
[stopRequested,accumulationUs,startRequested]=app.readViewerCommandState(commands,5000);
verifyFalse(testCase,stopRequested);
verifyEqual(testCase,accumulationUs,5000);
verifyTrue(testCase,startRequested);
end

function testCameraBatchCommandDoesNotChangeDisplayWindow(testCase)
commands={struct("type","setBatchTimeUs","value",33333)};
[stopRequested,accumulationUs,startRequested]= ...
    app.readViewerCommandState(commands,5000);

verifyFalse(testCase,stopRequested);
verifyEqual(testCase,accumulationUs,5000);
verifyFalse(testCase,startRequested);
end

