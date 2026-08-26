function outline = traceBoundary(mask)
% Trace the outer 8-connected boundary without Image Processing Toolbox.
arguments
    mask (:,:) logical
end

if ~any(mask(:))
    outline = zeros(0,2);
    return
end

neighborCount = conv2(double(mask),ones(3),"same");
perimeter = mask & neighborCount < 9;
[rows,columns] = find(perimeter);
if isempty(rows)
    outline = zeros(0,2);
    return
end

[~,startIndex] = min((rows-1) * size(mask,2) + columns);
start = [columns(startIndex),rows(startIndex)];
directions = [ ...
    -1  0
    -1 -1
     0 -1
     1 -1
     1  0
     1  1
     0  1
    -1  1];

current = start;
backtrack = start + directions(1,:);
outline = current;
maxSteps = max(8,nnz(perimeter) * 8);

for step = 1:maxSteps
    directionIndex = localDirectionIndex(backtrack-current,directions);
    found = false;
    for offset = 1:8
        candidateIndex = mod(directionIndex + offset - 1,8) + 1;
        candidate = current + directions(candidateIndex,:);
        if localIsPerimeter(perimeter,candidate)
            found = true;
            break
        end
    end
    if ~found
        break
    end

    if isequal(candidate,start) && size(outline,1) > 2
        outline(end+1,:) = candidate; %#ok<AGROW>
        return
    end

    outline(end+1,:) = candidate; %#ok<AGROW>
    backtrack = current + directions(mod(candidateIndex - 2,8) + 1,:);
    current = candidate;
end

if size(outline,1) > 1 && ~isequal(outline(1,:),outline(end,:))
    outline(end+1,:) = outline(1,:); %#ok<AGROW>
end
end

function index = localDirectionIndex(vector,directions)
index = find(directions(:,1) == vector(1) & directions(:,2) == vector(2),1);
if isempty(index)
    index = 1;
end
end

function tf = localIsPerimeter(perimeter,point)
column = point(1);
row = point(2);
tf = row >= 1 && row <= size(perimeter,1) && ...
    column >= 1 && column <= size(perimeter,2) && perimeter(row,column);
end
