function tests=testEventCountDisplaySource
tests=functiontests(localfunctions);
end

function testDisplayedEventCountComesFromCurrentAcquisitionBatch(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
source=fileread(fullfile(root,"src","matlab","+app","run.m"));
verifyTrue(testCase,contains(source,'"eventCount",numel(packet.timestamp)'));
end

