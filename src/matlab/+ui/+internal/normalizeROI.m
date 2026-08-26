function rectangle = normalizeROI(rectangle,resolution)
arguments
    rectangle (1,4) {mustBeNumeric}
    resolution (1,2) {mustBeNumeric}
end

height = max(1,round(double(resolution(1))));
width = max(1,round(double(resolution(2))));
values = double(rectangle);
if any(~isfinite(values))
    error("DVSense:InvalidROI","ROI必须是有限的矩形坐标。");
end

x0 = min(values(1),values(1)+values(3));
x1 = max(values(1),values(1)+values(3));
y0 = min(values(2),values(2)+values(4));
y1 = max(values(2),values(2)+values(4));
x0 = max(1,min(width,floor(x0)));
x1 = max(1,min(width,ceil(x1)));
y0 = max(1,min(height,floor(y0)));
y1 = max(1,min(height,ceil(y1)));

if x1 < x0, [x0,x1] = deal(x1,x0); end
if y1 < y0, [y0,y1] = deal(y1,y0); end
rectangle = [x0 y0 max(1,x1-x0+1) max(1,y1-y0+1)];
end
