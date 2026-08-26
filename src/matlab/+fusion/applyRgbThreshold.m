function output = applyRgbThreshold(frame, threshold)
arguments
    frame
    threshold (1,1) double {mustBeFinite} = 0
end

threshold = round(max(0,min(255,threshold)));
if isempty(frame)
    output = frame;
    return
end

if ~isa(frame,"uint8")
    frame = im2uint8(frame);
end
if ndims(frame) == 2
    frame = repmat(frame,1,1,3);
elseif size(frame,3) ~= 3
    error("DVSense:FusionRgbShape", ...
        "RGB frame must be HxWx3 or a 2-D intensity image.");
end

if threshold <= 0
    output = frame;
    return
end

red = double(frame(:,:,1));
green = double(frame(:,:,2));
blue = double(frame(:,:,3));
luminance = 0.299*red + 0.587*green + 0.114*blue;
mask = luminance < threshold;
output = frame;
for channel = 1:3
    plane = output(:,:,channel);
    plane(mask) = 0;
    output(:,:,channel) = plane;
end
end
