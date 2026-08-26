function tests=testProcessingReset
tests=functiontests(localfunctions);
end

function testAccumulatorResetDropsPendingWindow(testCase)
accumulator=analysis.RecognitionWindow(uint64(1000),100);
packet=localPacket(uint64([100;500]));
accumulator.add(packet);

accumulator.reset();

verifyFalse(testCase,accumulator.ready());
verifyError(testCase,@()accumulator.take(),"DVSense:EmptyRecognitionWindow");
end

function testAccumulatorReadyWhenEnoughEventsArriveBeforeTimeWindow(testCase)
accumulator=analysis.RecognitionWindow(uint64(5000),100,4);
packet=struct("x",uint16((1:4).'),"y",uint16((1:4).'), ...
    "polarity",true(4,1),"timestamp",uint64([100;100;100;100]), ...
    "resolution",[10 10],"roiOffset",[0 0], ...
    "timeStartUs",uint64(100),"timeEndUs",uint64(100));
accumulator.add(packet);

verifyTrue(testCase,accumulator.ready());
recognitionPacket=accumulator.take();
verifyNumElements(testCase,recognitionPacket.x,4);
end

function testTrackerResetClearsTimestampAndState(testCase)
cfg=struct("processNoise",30,"measurementNoise",8, ...
    "initialCovariance",100);
tracker=analysis.MotionTracker(cfg);
measurement=struct("valid",true,"position",[4;5], ...
    "boundingBox",[1 2 3 4],"confidence",1);
tracker.step(measurement,uint64(5000));

tracker.reset();

verifyFalse(testCase,tracker.Initialized);
verifyEqual(testCase,tracker.LastTimestampUs,uint64(0));
verifyEqual(testCase,tracker.State,zeros(4,1));
verifyEqual(testCase,tracker.Covariance,eye(4)*100);
end

function testRiserBackendReportsCpuFallbackTruthfully(testCase)
cfg=localConfig;
backend=analysis.GpuRiserAnalysisBackend(cfg);

status=backend.status();

verifyEqual(testCase,string(status.requested),"matlab-gpu");
verifyEqual(testCase,string(status.executed),"cpu");
verifyTrue(testCase,status.fallback);
end

function packet=localPacket(timestamp)
packet=struct("x",uint16([1;2]),"y",uint16([1;2]), ...
    "polarity",logical([1;0]),"timestamp",timestamp, ...
    "resolution",[10 10],"roiOffset",[0 0], ...
    "timeStartUs",min(timestamp),"timeEndUs",max(timestamp));
end

function cfg=localConfig
cfg.compute.backend="matlab-gpu";
cfg.compute.allowFallback=true;
cfg.processing=struct();
cfg.tracking=struct("minimumEvents",1,"trimFraction",0);
cfg.source.eventsPerWindow=10;
end

