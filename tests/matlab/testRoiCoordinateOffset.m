function tests = testRoiCoordinateOffset
tests = functiontests(localfunctions);
end

function testRoiOffsetMovesAnalysisGeometryBackToDisplayCoordinates(testCase)
result = struct("outline",[1 1; 5 1], ...
    "centerline",[2 3; 2 4], ...
    "position",[2;3], ...
    "velocity",[4;5],"acceleration",[6;7]);

result = analysis.applyRoiOffset(result,[19 39]);

verifyEqual(testCase,result.outline,[20 40; 24 40]);
verifyEqual(testCase,result.centerline,[21 42; 21 43]);
verifyEqual(testCase,result.position,[21;42]);
verifyEqual(testCase,result.velocity,[4;5]);
verifyEqual(testCase,result.acceleration,[6;7]);
end

