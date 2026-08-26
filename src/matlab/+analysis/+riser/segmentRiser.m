function [mask,primaryMask] = segmentRiser(image,config,timeSurface)
% Segment all connected, high-density event components and keep one
% primary component for downstream centerline and motion estimates.
arguments
    image (:,:) {mustBeNumeric}
    config struct = struct
    timeSurface = []
end
mask = false(size(image));
primaryMask = false(size(image));
if isempty(image) || ~any(image(:)), return; end
threshold = 0;
if isfield(config,"threshold"), threshold = max(0,double(config.threshold)); end
values = double(image);
minArea = 8;
if isfield(config,"minComponentArea"), minArea = max(1,round(double(config.minComponentArea))); end
minThickness = 2;
if isfield(config,"minComponentThickness")
    minThickness = max(1,round(double(config.minComponentThickness)));
end
mergeGap = 10;
if isfield(config,"componentMergeGap")
    mergeGap = max(0,double(config.componentMergeGap));
end
if threshold >= 1
    thresholdValues = threshold;
else
    maximumValue = max(values(:));
    hasFractionalWeights = any(values(:) ~= floor(values(:)));
    fractions = unique([threshold, max(0.1,threshold*0.5), max(0.05,threshold*0.25)]);
    thresholdValues = zeros(size(fractions));
    for index = 1:numel(fractions)
        if hasFractionalWeights
            thresholdValues(index) = max(eps,maximumValue * fractions(index));
        else
            thresholdValues(index) = max(1,ceil(maximumValue * fractions(index)));
        end
    end
end
thresholdValues = unique([thresholdValues(:); localPositiveThresholds(values)]);

bestArea = 0;
bestScore = -Inf;
bestMask = false(size(values));
bestPrimaryMask = false(size(values));
timeRange = localTimeRange(timeSurface);
for thresholdIndex = 1:numel(thresholdValues)
    thresholdValue = thresholdValues(thresholdIndex);
    [candidateMask,candidatePrimaryMask] = selectComponents(values >= thresholdValue, ...
        minArea,minThickness,mergeGap,timeSurface,timeRange);
    candidateArea = nnz(candidateMask);
    if candidateArea <= 0
        continue
    end
    candidateScore = candidateArea;
    if candidateScore > bestScore || ...
            (candidateScore == bestScore && candidateArea > bestArea)
        bestMask = candidateMask;
        bestPrimaryMask = candidatePrimaryMask;
        bestArea = candidateArea;
        bestScore = candidateScore;
    end
end
mask = bestMask;
primaryMask = bestPrimaryMask;
end

function [mask,primaryMask] = selectComponents(candidate,minArea,minThickness,mergeGap, ...
    timeSurface,timeRange)
components = connectedComponents(candidate);
mask = false(size(candidate));
primaryMask = false(size(candidate));
if isempty(components)
    return
end
componentSizes = cellfun(@numel,components);
componentThickness = zeros(size(componentSizes));
for componentIndex = 1:numel(components)
    [rows,columns] = ind2sub(size(candidate),components{componentIndex});
    componentThickness(componentIndex) = min( ...
        max(rows)-min(rows)+1,max(columns)-min(columns)+1);
end
validComponents = find(componentSizes >= minArea & ...
    componentThickness >= minThickness);
if isempty(validComponents)
    validComponents = find(componentSizes >= minArea);
end
if isempty(validComponents)
    return
end
pending = validComponents(:).';
groupMasks = cell(0,1);
groupAreas = zeros(0,1);
groupScores = zeros(0,1);
while ~isempty(pending)
    seed = pending(1);
    pending(1) = [];
    groupMask = false(size(candidate));
    groupMask(components{seed}) = true;
    changed = true;
    while changed && ~isempty(pending) && mergeGap > 0
        changed = false;
        selectedComponents = findSelectedComponents(groupMask,components);
        distances = arrayfun(@(index)componentGap( ...
            components{index},selectedComponents,size(candidate)),pending);
        mergeIndices = find(distances <= mergeGap);
        if ~isempty(mergeIndices)
            mergedIndices = pending(mergeIndices);
            for mergeIndex = reshape(mergedIndices,1,[])
                groupMask(components{mergeIndex}) = true;
            end
            pending(mergeIndices) = [];
            changed = true;
        end
    end
    groupMask = closeSmallGaps(groupMask);
    groupMasks{end+1,1} = groupMask; %#ok<AGROW>
    groupAreas(end+1,1) = nnz(groupMask); %#ok<AGROW>
    groupScores(end+1,1) = localCandidateScore(groupMask,timeSurface,timeRange); %#ok<AGROW>
end
if isempty(groupMasks)
    return
end
mask = false(size(candidate));
for index = 1:numel(groupMasks)
    mask = mask | groupMasks{index};
end
[~,primaryIndex] = max(groupScores);
if groupScores(primaryIndex) <= 0
    [~,primaryIndex] = max(groupAreas);
end
primaryMask = groupMasks{primaryIndex};
end

function selectedComponents = findSelectedComponents(selectedMask,components)
selectedComponents = cell(0,1);
for index = 1:numel(components)
    if any(selectedMask(components{index}))
        selectedComponents{end+1} = components{index}; %#ok<AGROW>
    end
end
end

function distance = componentGap(component,selectedComponents,imageSize)
[rows,columns] = ind2sub(imageSize,component);
currentBox = [min(columns) min(rows) max(columns) max(rows)];
distance = Inf;
for index = 1:numel(selectedComponents)
    [rows,columns] = ind2sub(imageSize,selectedComponents{index});
    selectedBox = [min(columns) min(rows) max(columns) max(rows)];
    horizontal = max([currentBox(1)-selectedBox(3)-1, ...
        selectedBox(1)-currentBox(3)-1,0]);
    vertical = max([currentBox(2)-selectedBox(4)-1, ...
        selectedBox(2)-currentBox(4)-1,0]);
    distance = min(distance,hypot(horizontal,vertical));
end
end

function components = connectedComponents(binary)
[h,w] = size(binary); visited = false(h,w); components = cell(0,1);
for start = find(binary(:)).'
    if visited(start), continue; end
    queue = zeros(nnz(binary),1); head = 1; tail = 1; queue(1) = start; visited(start) = true;
    component = zeros(nnz(binary),1); count = 0;
    while head <= tail
        current = queue(head); head = head + 1; count = count + 1; component(count) = current;
        [row,column] = ind2sub([h w],current);
        for dr = -1:1
            for dc = -1:1
                if dr == 0 && dc == 0, continue; end
                nextRow = row + dr; nextColumn = column + dc;
                if nextRow < 1 || nextRow > h || nextColumn < 1 || nextColumn > w, continue; end
                next = sub2ind([h w],nextRow,nextColumn);
                if binary(next) && ~visited(next)
                    tail = tail + 1; queue(tail) = next; visited(next) = true;
                end
            end
        end
    end
    components{end+1,1} = component(1:count); %#ok<AGROW>
end
end

function output = closeSmallGaps(input)
kernel = ones(3); dilated = conv2(double(input),kernel,"same") > 0;
output = conv2(double(dilated),kernel,"same") == numel(kernel);
end

function range = localTimeRange(timeSurface)
range = [NaN NaN];
if isempty(timeSurface) || ~isnumeric(timeSurface)
    return
end
finiteValues = double(timeSurface(isfinite(timeSurface)));
if isempty(finiteValues)
    return
end
range = [min(finiteValues),max(finiteValues)];
end

function thresholds = localPositiveThresholds(values)
positiveValues = double(values(values > 0));
if isempty(positiveValues)
    thresholds = zeros(0,1);
    return
end
positiveValues = sort(positiveValues(:));
samplePoints = unique(max(1,ceil(numel(positiveValues) .* [0.5 0.75 0.9])));
thresholds = positiveValues(samplePoints);
thresholds = thresholds(:);
end

function score = localCandidateScore(mask,timeSurface,timeRange)
area = nnz(mask);
if area <= 0
    score = 0;
    return
end
if isempty(timeSurface) || any(isnan(timeRange))
    freshness = 1;
else
    componentTimes = double(timeSurface(mask));
    componentTimes = componentTimes(isfinite(componentTimes));
    if isempty(componentTimes) || timeRange(2) <= timeRange(1)
        freshness = 1;
    else
        freshness = (mean(componentTimes) - timeRange(1)) / (timeRange(2) - timeRange(1));
        freshness = max(0,min(1,freshness));
    end
end
score = (area ^ 0.8) * max(eps,freshness);
end
