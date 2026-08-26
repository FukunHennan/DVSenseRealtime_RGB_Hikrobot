function [image,timeSurface] = buildEventImage(packet,config)
% Convert one bounded event packet into count and latest-time images.
arguments
    packet (1,1) struct
    config struct = struct
end
validatePacket(packet);
h = double(packet.resolution(1)); w = double(packet.resolution(2));
decayUs = 0;
if isfield(config,"temporalDecayUs")
    decayUs = max(0,double(config.temporalDecayUs));
end
if decayUs > 0
    image = zeros(h,w,"single");
else
    image = zeros(h,w,"uint16");
end
timeSurface = nan(h,w);
if isempty(packet.x), return; end
x = double(packet.x(:)); y = double(packet.y(:));
valid = x >= 1 & x <= w & y >= 1 & y <= h;
indices = sub2ind([h w],y(valid),x(valid));
counts = accumarray(indices,1,[h*w 1],@sum,0);
if decayUs == 0
    image(:) = uint16(min(counts,double(intmax("uint16"))));
end
timestamps = double(packet.timestamp(:));
if numel(timestamps) ~= numel(packet.x)
    timestamps = repmat(double(packet.timeEndUs),numel(packet.x),1);
end
for index = find(valid).'
    pixelIndex = sub2ind([h w],y(index),x(index));
    timeSurface(pixelIndex) = max(timeSurface(pixelIndex),timestamps(index));
end
if decayUs > 0 && any(valid)
    latest = max(timestamps(valid));
    age = max(0,latest - timestamps(valid));
    weights = max(0,1 - age ./ decayUs);
    image(:) = single(accumarray(indices,weights,[h*w 1],@sum,0));
end
end

function validatePacket(packet)
required = ["x","y","polarity","timestamp","resolution","timeStartUs","timeEndUs"];
if ~all(isfield(packet,cellstr(required)))
    error("DVSense:RiserPacket","Packet is missing a required field.");
end
if numel(packet.x) ~= numel(packet.y) || numel(packet.x) ~= numel(packet.polarity)
    error("DVSense:RiserPacket","Event arrays must have equal lengths.");
end
if numel(packet.resolution) ~= 2 || any(double(packet.resolution) < 1)
    error("DVSense:RiserPacket","Resolution must be [height width].");
end
end
