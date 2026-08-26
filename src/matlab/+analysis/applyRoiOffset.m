function result = applyRoiOffset(result,roiOffset)
arguments
    result (1,1) struct
    roiOffset (1,2) {mustBeNumeric}
end

offset = double(roiOffset);
if any(~isfinite(offset)) || all(offset == 0)
    return
end

if isfield(result,"outline") && ~isempty(result.outline)
    result.outline = double(result.outline) + offset;
end
if isfield(result,"centerline") && ~isempty(result.centerline)
    result.centerline = double(result.centerline) + offset;
end
if isfield(result,"position") && numel(result.position) == 2 && ...
        all(isfinite(result.position))
    result.position = double(result.position(:)) + offset(:);
end
end
