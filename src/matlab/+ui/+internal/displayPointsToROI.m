function rectangle = displayPointsToROI(startPoint,endPoint,scale,resolution)
arguments
    startPoint (1,2) {mustBeNumeric}
    endPoint (1,2) {mustBeNumeric}
    scale (1,1) double {mustBePositive}
    resolution (1,2) {mustBeNumeric}
end

startPoint = double(startPoint);
endPoint = double(endPoint);
if any(~isfinite([startPoint endPoint]))
    error("DVSense:InvalidROI","ROI拖拽坐标必须是有限值。");
end

sourceStart = floor((startPoint-1)/scale)+1;
sourceEnd = ceil((endPoint-1)/scale)+1;
rectangle = ui.internal.normalizeROI( ...
    [sourceStart sourceEnd-sourceStart],resolution);
end
