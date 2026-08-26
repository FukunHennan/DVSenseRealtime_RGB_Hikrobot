function tests = testRiserAnalysisPipeline
tests = functiontests(localfunctions);
end

function testFixtureIsDeterministicAndHasExpectedPacketContract(testCase)
fixture = loadFixture();
verifyNumElements(testCase,fixture.packets,3);
verifyEqual(testCase,fixture.packets{1}.resolution,fixture.expected.resolution);
verifyClass(testCase,fixture.packets{1}.x,"uint16");
verifyClass(testCase,fixture.packets{1}.timestamp,"uint64");
verifyEqual(testCase,fixture.packets{1}.x,fixture.packets{1}.x);
end

function testPipelineExtractsCurvedGeometryAndFixedResultContract(testCase)
fixture = loadFixture();
pipeline = analysis.RiserAnalysisPipeline(localConfig);
result = pipeline.process(fixture.packets{1});

verifyTrue(testCase,result.valid);
verifyEqual(testCase,string(fieldnames(result)),[ ...
    "valid";"timestampUs";"mask";"outline";"outlines";"centerline"; ...
    "curvature";"position";"velocity";"acceleration";"confidence";"state"; ...
    "status";"reason";"rawEventCount";"filteredEventCount"; ...
    "maskPixelCount";"outlinePointCount";"centerlinePointCount";"windowReady"]);
verifySize(testCase,result.mask,fixture.expected.resolution);
verifyGreaterThan(testCase,size(result.outline,1),20);
verifyGreaterThan(testCase,size(result.centerline,1),20);
verifyEqual(testCase,size(result.centerline,2),2);
verifyEqual(testCase,size(result.curvature),[size(result.centerline,1) 1]);
verifyGreaterThan(testCase,range(result.centerline(:,1)),8);
verifyGreaterThan(testCase,result.confidence,0.2);
verifyEqual(testCase,result.state,"stable");
verifyEqual(testCase,result.status,"valid");
verifyTrue(testCase,result.windowReady);
verifyGreaterThan(testCase,result.maskPixelCount,0);
verifyGreaterThan(testCase,result.outlinePointCount,0);
verifyGreaterThan(testCase,result.centerlinePointCount,0);
end

function testExtractOutlineReturnsOrderedContourPath(testCase)
mask = false(8,10);
mask(3:6,4:8) = true;
outline = analysis.riser.extractOutline(mask);

verifyGreaterThan(testCase,size(outline,1),0);
verifyEqual(testCase,size(outline,2),2);
steps = abs(diff(outline,1,1));
verifyTrue(testCase,all(sum(steps,2) <= 2));
verifyLessThanOrEqual(testCase,max(vecnorm(diff([outline; outline(1,:)],1,1),2,2)),2);
end

function testExtractOutlineReturnsMultipleClosedPaths(testCase)
mask = false(16,20);
mask(3:6,4:7) = true;
mask(10:13,12:16) = true;

outline = analysis.riser.extractOutline(mask);

verifyGreaterThan(testCase,nnz(all(isnan(outline),2)),0);
verifyGreaterThan(testCase,sum(all(isfinite(outline),2)),8);
end

function testEventImagePrefersRecentActivityOverStaleRepeatEvents(testCase)
packet = struct( ...
    "x",uint16([repmat(5,20,1);8]), ...
    "y",uint16(repmat(5,21,1)), ...
    "polarity",true(21,1), ...
    "timestamp",uint64([ones(20,1,"uint64");20000]), ...
    "resolution",[12 16], ...
    "timeStartUs",uint64(1), ...
    "timeEndUs",uint64(20000));

[image,timeSurface] = analysis.riser.buildEventImage(packet, ...
    struct("temporalDecayUs",1000));

verifyGreaterThan(testCase,image(5,8),image(5,5));
verifyEqual(testCase,timeSurface(5,5),1);
verifyEqual(testCase,timeSurface(5,8),20000);
end

function testEventImagePreservesFractionalTemporalDecay(testCase)
packet = struct( ...
    "x",uint16([5;8]), ...
    "y",uint16([5;5]), ...
    "polarity",true(2,1), ...
    "timestamp",uint64([1000;1500]), ...
    "resolution",[12 16], ...
    "timeStartUs",uint64(1000), ...
    "timeEndUs",uint64(1500));

image = analysis.riser.buildEventImage(packet,struct("temporalDecayUs",1000));

verifyGreaterThan(testCase,double(image(5,5)),0);
verifyLessThan(testCase,double(image(5,5)),double(image(5,8)));
verifyEqual(testCase,double(image(5,8)),1,"AbsTol",1e-12);
end

function testPipelinePrefersNewestPoseOverRecentTrail(testCase)
resolution = [90 130];
[trailX,trailY] = meshgrid(18:42,25:63);
[poseX,poseY] = meshgrid(92:98,28:60);
packet = struct( ...
    "x",uint16([trailX(:); poseX(:)]), ...
    "y",uint16([trailY(:); poseY(:)]), ...
    "polarity",true(numel(trailX)+numel(poseX),1), ...
    "timestamp",uint64([repmat(2500,numel(trailX),1); ...
        repmat(3000,numel(poseX),1)]), ...
    "resolution",resolution, ...
    "timeStartUs",uint64(2500), ...
    "timeEndUs",uint64(3000));
cfg = localConfig;
cfg.processing.temporalDecayUs = uint64(2000);
cfg.processing.threshold = 0.8;
cfg.processing.minComponentArea = 20;
cfg.processing.minComponentThickness = 2;

result = analysis.RiserAnalysisPipeline(cfg).process(packet);

verifyTrue(testCase,result.valid);
verifyGreaterThan(testCase,result.position(1),85);
verifyLessThan(testCase,min(result.outline(:,1)),105);
end

function testPipelineRecoversContourWhenConfiguredThresholdIsTooStrict(testCase)
fixture = loadFixture();
cfg = localConfig;
cfg.processing.threshold = 0.8;

result = analysis.RiserAnalysisPipeline(cfg).process(fixture.packets{1});

verifyTrue(testCase,result.valid);
verifyGreaterThan(testCase,result.maskPixelCount,200);
verifyGreaterThan(testCase,size(result.outline,1),40);
verifyGreaterThan(testCase,range(result.outline(:,2)),50);
end

function testTraceBoundaryKeepsConcavePerimeterContinuous(testCase)
mask = false(18,18);
mask(4:14,4:7) = true;
mask(11:14,4:14) = true;
mask(4:7,11:14) = true;

outline = analysis.riser.traceBoundary(mask);

verifyGreaterThan(testCase,size(outline,1),24);
verifyEqual(testCase,outline(1,:),outline(end,:));
steps = abs(diff(outline,1,1));
verifyTrue(testCase,all(max(steps,[],2) <= 1));
verifyGreaterThanOrEqual(testCase,max(outline(:,1)),14);
verifyGreaterThanOrEqual(testCase,max(outline(:,2)),14);
end

function testSegmentRiserRetainsSecondaryConnectedRegion(testCase)
image = zeros(24,32,"uint16");
image(3:8,4:8) = 10;
image(16:18,23:30) = 10;

mask = analysis.riser.segmentRiser(image, ...
    struct("threshold",0.5,"minComponentArea",4));

verifyTrue(testCase,all(mask(3:8,4:8),"all"));
verifyTrue(testCase,all(mask(16:18,23:30),"all"));
end

function testSegmentRiserClosesInteriorGapWithoutGrowingOuterMask(testCase)
image = zeros(24,32,"uint16");
image(6:14,8:16) = 10;
image(10,12) = 0;

mask = analysis.riser.segmentRiser(image, ...
    struct("threshold",0.5,"minComponentArea",4));

verifyTrue(testCase,mask(10,12));
verifyFalse(testCase,mask(4,6));
verifyFalse(testCase,mask(16,18));
end

function testSegmentRiserRejectsLongThinNoiseInFavorOfThickerTarget(testCase)
image = zeros(32,48,"uint16");
image(6:13,32:35) = 10;
image(22,3:43) = 10;

mask = analysis.riser.segmentRiser(image, ...
    struct("threshold",0.5,"minComponentArea",4));

verifyTrue(testCase,all(mask(6:13,32:35),"all"));
verifyFalse(testCase,any(mask(22,3:43),"all"));
end

function testSegmentRiserRetainsNearbyFragmentsAndSeparateRegion(testCase)
image = zeros(90,110,"uint16");
image(36:62,35:68) = 10;
image(8:29,40:46) = 10;
image(8:29,56:62) = 10;
image(70:75,88:98) = 10;

mask = analysis.riser.segmentRiser(image, ...
    struct("threshold",0.5,"minComponentArea",20, ...
    "componentMergeGap",8));

verifyTrue(testCase,all(mask(36:62,35:68),"all"));
verifyTrue(testCase,all(mask(8:29,40:46),"all"));
verifyTrue(testCase,all(mask(8:29,56:62),"all"));
verifyTrue(testCase,all(mask(70:75,88:98),"all"));
end

function testSegmentRiserRetainsContainingBodyAndHotspot(testCase)
image = zeros(90,110,"single");
image(25:60,30:70) = 1;
image(40:45,50:55) = 5;

mask = analysis.riser.segmentRiser(image, ...
    struct("threshold",0.8,"minComponentArea",20));

verifyTrue(testCase,all(mask(25:60,30:70),"all"));
verifyTrue(testCase,all(mask(40:45,50:55),"all"));
end

function testSegmentRiserRetainsDimBodyAndBrightHotspot(testCase)
image = zeros(72,120,"single");
image(20:45,18:78) = 0.35;
image(9:12,92:96) = 5;

mask = analysis.riser.segmentRiser(image, ...
    struct("threshold",0.8,"minComponentArea",20, ...
    "minComponentThickness",2,"componentMergeGap",0));

verifyTrue(testCase,all(mask(20:45,18:78),"all"));
verifyTrue(testCase,all(mask(9:12,92:96),"all"));
end

function testPipelineExposesAllHighActivityContours(testCase)
resolution = [80 120];
[x1,y1] = meshgrid(10:26,12:28);
[x2,y2] = meshgrid(70:92,42:60);
packet = struct( ...
    "x",uint16([x1(:);x2(:)]), ...
    "y",uint16([y1(:);y2(:)]), ...
    "polarity",true(numel(x1)+numel(x2),1), ...
    "timestamp",uint64([repmat(1000,numel(x1),1);repmat(2000,numel(x2),1)]), ...
    "resolution",resolution, ...
    "timeStartUs",uint64(1000), ...
    "timeEndUs",uint64(2000));
cfg = localConfig;
cfg.processing.threshold = 0.5;
cfg.processing.minComponentArea = 20;

pipeline = analysis.RiserAnalysisPipeline(cfg);
result = pipeline.process(packet);

verifyGreaterThan(testCase,nnz(all(isnan(result.outlines),2)),0);
verifyTrue(testCase,all(result.mask(12:28,10:26),"all"));
verifyTrue(testCase,all(result.mask(42:60,70:92),"all"));
end

function testPipelineProducesDeterministicOutput(testCase)
fixture = loadFixture();
resultA = analysis.RiserAnalysisPipeline(localConfig).process(fixture.packets{1});
resultB = analysis.RiserAnalysisPipeline(localConfig).process(fixture.packets{1});
verifyEqual(testCase,resultA.mask,resultB.mask);
verifyEqual(testCase,resultA.centerline,resultB.centerline,"AbsTol",1e-12);
verifyEqual(testCase,resultA.curvature,resultB.curvature,"AbsTol",1e-12);
end

function testPipelineEstimatesMotionAcrossPackets(testCase)
fixture = loadFixture();
pipeline = analysis.RiserAnalysisPipeline(localConfig);
pipeline.process(fixture.packets{1});
pipeline.process(fixture.packets{2});
result = pipeline.process(fixture.packets{3});
verifyTrue(testCase,result.valid);
verifyGreaterThan(testCase,result.velocity(1),0);
verifyGreaterThan(testCase,result.confidence,0.2);
verifyEqual(testCase,result.state,"moving");
end

function testPipelineRejectsSparseInput(testCase)
fixture = loadFixture();
packet = fixture.packets{1};
packet.x = packet.x(1:3);
packet.y = packet.y(1:3);
packet.polarity = packet.polarity(1:3);
packet.timestamp = packet.timestamp(1:3);
result = analysis.RiserAnalysisPipeline(localConfig).process(packet);
verifyFalse(testCase,result.valid);
verifyEqual(testCase,result.state,"invalid");
verifyEqual(testCase,result.confidence,0);
verifyTrue(testCase,all(isnan(result.position)));
verifyEqual(testCase,result.status,"mask-empty");
verifyEqual(testCase,result.reason,"活动滤波后未分割出目标。");
verifyEqual(testCase,result.rawEventCount,3);
verifyEqual(testCase,result.filteredEventCount,3);
verifyEqual(testCase,result.maskPixelCount,0);
verifyEqual(testCase,result.outlinePointCount,0);
verifyEqual(testCase,result.centerlinePointCount,0);
verifyFalse(testCase,result.windowReady);
end

function testPipelineReportsWaitingStateForEmptyPacket(testCase)
packet = struct( ...
    "x",uint16([]), ...
    "y",uint16([]), ...
    "polarity",false(0,1), ...
    "timestamp",uint64([]), ...
    "resolution",[72 128], ...
    "timeStartUs",uint64(0), ...
    "timeEndUs",uint64(0));
result = analysis.RiserAnalysisPipeline(localConfig).process(packet);

verifyFalse(testCase,result.valid);
verifyEqual(testCase,result.status,"waiting-events");
verifyEqual(testCase,result.reason,"当前识别窗口没有事件。");
verifyEqual(testCase,result.rawEventCount,0);
verifyEqual(testCase,result.filteredEventCount,0);
verifyEqual(testCase,result.maskPixelCount,0);
verifyEqual(testCase,result.outlinePointCount,0);
verifyEqual(testCase,result.centerlinePointCount,0);
verifyFalse(testCase,result.windowReady);
end

function testGpuBackendKeepsRecognitionInterface(testCase)
fixture = loadFixture();
backend = analysis.GpuRiserAnalysisBackend(localConfig);
result = backend.process(fixture.packets{1});
verifyTrue(testCase,isfield(result,"mask"));
verifyTrue(testCase,any(backend.BackendUsed == ["cpu" "gpu"]));
end

function fixture = loadFixture()
fixture = load(fullfile(fileparts(fileparts(fileparts(mfilename("fullpath")))),"tests","fixtures","riserEvents.mat"));
end

function cfg = localConfig
cfg.source.eventsPerWindow = 1000;
cfg.processing.minimumEvents = 20;
cfg.processing.minComponentArea = 20;
cfg.processing.threshold = 0.20;
cfg.processing.morphologyRadius = 1;
cfg.processing.centerlineSmoothing = 5;
cfg.processing.temporalDecayUs = uint64(2000);
cfg.tracking.motionThresholdPxPerS = 0.05;
cfg.compute.backend = "cpu";
end

