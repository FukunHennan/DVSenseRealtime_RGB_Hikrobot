function outline = extractOutline(mask)
% Return an ordered closed contour path as [x y] coordinates.
arguments
    mask (:,:) logical
end
if ~any(mask(:)), outline = zeros(0,2); return; end

if exist("bwboundaries","file") == 2
    boundaries = bwboundaries(mask,"noholes");
    outline = localCombineBoundaries(boundaries);
    return
end

components = localConnectedComponents(mask);
outline = zeros(0,2);
for index = 1:numel(components)
    componentMask = false(size(mask));
    componentMask(components{index}) = true;
    boundary = analysis.riser.traceBoundary(componentMask);
    outline = localAppendOutline(outline,boundary);
end
end

function outline = localCombineBoundaries(boundaries)
outline = zeros(0,2);
for index = 1:numel(boundaries)
    boundary = boundaries{index};
    if size(boundary,1) < 2
        continue
    end
    segment = [boundary(:,2),boundary(:,1)];
    if ~isequal(segment(1,:),segment(end,:))
        segment(end+1,:) = segment(1,:); %#ok<AGROW>
    end
    outline = localAppendOutline(outline,segment);
end
end

function outline = localAppendOutline(outline,segment)
if isempty(segment)
    return
end
if ~isempty(outline)
    outline(end+1,:) = [NaN NaN]; %#ok<AGROW>
end
outline = [outline; segment]; %#ok<AGROW>
end

function components = localConnectedComponents(binary)
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
