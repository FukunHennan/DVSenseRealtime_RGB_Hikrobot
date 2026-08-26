function createRiserEventsFixture(outputPath)
% Create a deterministic curved-riser event sequence for recognition tests.
if nargin < 1
    outputPath = fullfile(fileparts(mfilename("fullpath")),"riserEvents.mat");
end

rng(1729,"twister");
resolution = [120 160];
packets = cell(1,3);
for frameIndex = 1:3
    y = (18:102).';
    xCenter = 48 + 0.10 .* (y - 18) + 9 .* sin((y - 18) ./ 18) + (frameIndex - 1) * 2;
    stripeX = round(xCenter + (-3:3));
    stripeY = repmat(y,1,size(stripeX,2));
    stripeX = stripeX(:);
    stripeY = stripeY(:);
    noiseCount = 90;
    noiseX = randi([1 resolution(2)],noiseCount,1);
    noiseY = randi([1 resolution(1)],noiseCount,1);
    x = [stripeX; noiseX];
    yAll = [stripeY; noiseY];
    packets{frameIndex} = struct( ...
        "x",uint16(x),"y",uint16(yAll), ...
        "polarity",logical(mod((1:numel(x)).',2)), ...
        "timestamp",uint64((frameIndex - 1) * 5000 + (1:numel(x)).'), ...
        "resolution",resolution, ...
        "timeStartUs",uint64((frameIndex - 1) * 5000 + 1), ...
        "timeEndUs",uint64(frameIndex * 5000));
end

expected = struct("resolution",resolution,"frameShiftPx",[0 2 4]);
save(outputPath,"packets","expected","-mat");
end
