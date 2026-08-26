function tests = testMeasurementBackends
tests = functiontests(localfunctions);
end

function testCpuMeasurement(testCase)
cfg = localConfig;
packet = localPacket;
backend = analysis.CpuMeasurementBackend;
m = backend.extractMeasurement(packet,cfg);
verifyTrue(testCase,m.valid);
verifyEqual(testCase,m.position,[15;25],"AbsTol",1e-9);
end

function testKalmanInitializes(testCase)
cfg = localConfig;
tracker = analysis.MotionTracker(cfg.tracking);
m = struct("valid",true,"position",[15;25], ...
    "boundingBox",[10 20 11 11],"confidence",1);
track = tracker.step(m,uint64(1000));
verifyTrue(testCase,track.valid);
verifyEqual(testCase,track.position,[15;25],"AbsTol",1e-9);
end

function testDisplayAccumulatorIsBounded(testCase)
accumulator=analysis.RecognitionWindow(uint64(0),3);
packet=localPacket;
packet.x=uint16([1;2;3;4;5]);
packet.y=uint16([5;4;3;2;1]);
packet.polarity=true(5,1);
packet.timestamp=uint64(1:5).';
packet.timeStartUs=uint64(1);
packet.timeEndUs=uint64(5);
accumulator.add(packet);
displayPacket=accumulator.take();
verifyEqual(testCase,displayPacket.x,uint16([3;4;5]));
verifyEqual(testCase,displayPacket.timestamp,uint64([3;4;5]));
end

function testCpuRenderKeepsFullResolution(testCase)
cfg=localConfig;
cfg.display.scale=1;
packet=localPacket;
packet.x=uint16([1;1280]);
packet.y=uint16([1;720]);
packet.polarity=[true;false];
packet.resolution=[720 1280];
backend=analysis.CpuMeasurementBackend;
frame=backend.render(packet,cfg);
verifyClass(testCase,frame,"uint8");
verifySize(testCase,frame,[720 1280]);
verifyEqual(testCase,frame(1,1),uint8(2));
verifyEqual(testCase,frame(720,1280),uint8(3));
verifyTrue(testCase,all(ismember(unique(frame),uint8([1;2;3]))));
end

function testActivityFilterRemovesIsolatedEvents(testCase)
cfg=localConfig;
cfg.processing.activityFilterEnabled=true;
cfg.processing.minimumNeighborSupport=1;
packet=localPacket;
packet.x=uint16([10;11;30]);
packet.y=uint16([20;20;35]);
packet.polarity=[true;true;false];
packet.timestamp=uint64([1;2;3]);
filter=analysis.ActivityFilter;
filtered=filter.apply(packet,cfg);
verifyEqual(testCase,filtered.x,uint16([10;11]));
verifyEqual(testCase,filtered.y,uint16([20;20]));
verifyEqual(testCase,filtered.timestamp,uint64([1;2]));
end

function testCpuRenderClearsPreviousFrame(testCase)
cfg=localConfig;
cfg.display.scale=1;
backend=analysis.CpuMeasurementBackend;
packet=localPacket;
packet.resolution=[40 40];
packet.timeEndUs=uint64(2);
frame=backend.render(packet,cfg);
verifyEqual(testCase,frame(20,10),uint8(2));

packet.x=uint16(30);
packet.y=uint16(35);
packet.polarity=false;
packet.timestamp=uint64(20);
packet.timeEndUs=uint64(20);
frame=backend.render(packet,cfg);
verifyEqual(testCase,frame(20,10),uint8(1));
verifyEqual(testCase,frame(35,30),uint8(3));
end

function testCpuMeasurementRejectsSparseOutliers(testCase)
cfg=localConfig;
cfg.tracking.minimumEvents=10;
cfg.tracking.trimFraction=0.05;
packet=localPacket;
packet.x=uint16([repmat((100:109).',2,1);1;1280]);
packet.y=uint16([repmat((200:209).',2,1);1;720]);
packet.polarity=true(size(packet.x));
packet.timestamp=uint64((1:numel(packet.x)).');
packet.resolution=[720 1280];
backend=analysis.CpuMeasurementBackend;
m=backend.extractMeasurement(packet,cfg);
verifyTrue(testCase,m.valid);
verifyLessThan(testCase,m.boundingBox(3),20);
verifyLessThan(testCase,m.boundingBox(4),20);
verifyEqual(testCase,m.position,[104.5;204.5],"AbsTol",1e-9);
end

function cfg = localConfig
cfg.tracking.minimumEvents=2;
cfg.tracking.processNoise=30;
cfg.tracking.measurementNoise=8;
cfg.tracking.initialCovariance=100;
cfg.source.eventsPerWindow=2;
cfg.compute.countClamp=8;
end

function packet = localPacket
packet.x=uint16([10;20]); packet.y=uint16([20;30]);
packet.polarity=[true;false]; packet.timestamp=uint64([1;2]);
packet.resolution=[40 40]; packet.roiOffset=[0 0];
end

