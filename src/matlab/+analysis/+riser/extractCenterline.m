function [centerline,curvature] = extractCenterline(mask,config)
% Reduce a filled riser mask to one smoothed center point per occupied row.
arguments
    mask (:,:) logical
    config struct = struct
end
[h,~] = size(mask); centerline = zeros(0,2);
for y = 1:h
    x = find(mask(y,:));
    if ~isempty(x), centerline(end+1,:) = [median(x) y]; %#ok<AGROW>
    end
end
if isempty(centerline), curvature = zeros(0,1); return; end
window = 5;
if isfield(config,"centerlineSmoothing"), window = max(1,round(double(config.centerlineSmoothing))); end
if window > 1 && size(centerline,1) > 2
    centerline(:,1) = movmean(centerline(:,1),window,"Endpoints","shrink");
end
if size(centerline,1) < 3, curvature = zeros(size(centerline,1),1); return; end
dx = gradient(centerline(:,1)); ddx = gradient(dx);
curvature = ddx ./ max((1 + dx.^2).^(3/2),eps);
end
