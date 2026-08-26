function result = loadRgbToDvsTransform(filePath)
arguments
    filePath (1,1) string
end

result = struct("valid",false,"matrix",eye(3),"reason","");
if strlength(filePath) == 0 || ~isfile(filePath)
    result.reason = "标定文件不存在：" + filePath;
    return
end

try
    data = jsondecode(fileread(filePath));
catch cause
    result.reason = "标定 JSON 读取失败：" + string(cause.message);
    return
end

[matrix,found] = findTransform(data);
if ~found
    result.reason = "标定文件中未找到 RGB→DVS 的 3×3 变换矩阵。";
    return
end
if any(~isfinite(matrix),"all") || abs(det(matrix)) < eps
    result.reason = "RGB→DVS 变换矩阵无效或不可逆。";
    return
end

matrix = double(matrix) ./ double(matrix(3,3));
result.valid = true;
result.matrix = matrix;
result.reason = "标定有效";
end

function [matrix,found] = findTransform(value)
matrix = eye(3);
found = false;
if ~isstruct(value), return, end

priorityNames = ["rgbToDvs","rgb_to_dvs","rgb2dvs", ...
    "rgbToDvsHomography","rgb_to_dvs_homography","homographyRgbToDvs"];
fields = string(fieldnames(value));
for name = priorityNames
    index = find(strcmpi(fields,name),1);
    if isempty(index), continue, end
    candidate = value.(fields(index));
    [matrix,found] = normalizeMatrix(candidate);
    if found, return, end
end

for index = 1:numel(fields)
    child = value.(fields(index));
    if isstruct(child)
        [matrix,found] = findTransform(child);
        if found, return, end
    end
end
end

function [matrix,found] = normalizeMatrix(value)
matrix = eye(3);
found = false;
if isnumeric(value)
    numeric = double(value);
    if isequal(size(numeric),[3 3])
        matrix = numeric;
        found = true;
    elseif numel(numeric) == 9
        matrix = reshape(numeric,[3 3]);
        found = true;
    end
elseif isstruct(value)
    names = string(fieldnames(value));
    for candidateName = ["matrix","H","data","value"]
        index = find(strcmpi(names,candidateName),1);
        if isempty(index), continue, end
        [matrix,found] = normalizeMatrix(value.(names(index)));
        if found, return, end
    end
end
end
