function tests = testRiserBackends
tests = functiontests(localfunctions);
end

function testFactoryUsesGpuWhenAvailable(testCase)
cfg = localConfig("matlab-gpu", false);

backend = analysis.MeasurementBackendFactory.create(cfg);

verifyTrue(testCase, ismember(backend.Name, ["matlab-gpu", "cpu"]));
verifyTrue(testCase, ismethod(backend, "extractMeasurement"));
verifyTrue(testCase, ismethod(backend, "render"));
if backend.Name == "matlab-gpu"
    verifyEqual(testCase, backend.Status, "GPU backend active");
end
end

function testFactoryReportsVisibleFallback(testCase)
cfg = localConfig("matlab-gpu", true);

backend = analysis.MeasurementBackendFactory.create(cfg);

if backend.Name == "cpu"
    verifyNotEmpty(testCase, backend.Status);
    verifySubstring(testCase, backend.Status, "fallback");
end
end

function testCpuAndGpuContractsHaveSameFields(testCase)
cfg = localConfig("cpu", true);
packet = struct("x", [1; 2; 3], "y", [4; 5; 6], ...
    "polarity", logical([1; 0; 1]), "resolution", [8 10]);

cpu = analysis.CpuMeasurementBackend;
measurement = cpu.extractMeasurement(packet, cfg);
frame = cpu.render(packet, cfg);

verifyEqual(testCase, string(fieldnames(measurement)), ...
    ["valid"; "position"; "boundingBox"; "confidence"]);
verifySize(testCase, frame, packet.resolution);
end

function cfg = localConfig(backendName, allowFallback)
cfg.compute.backend = backendName;
cfg.compute.allowFallback = allowFallback;
cfg.tracking.minimumEvents = 1;
cfg.tracking.trimFraction = 0;
cfg.source.eventsPerWindow = 3;
cfg.display.scale = 1;
end

function verifySubstring(testCase, actual, expected)
verifyTrue(testCase, contains(lower(string(actual)), lower(string(expected))), ...
    "Expected '%s' to contain '%s'.", actual, expected);
end

