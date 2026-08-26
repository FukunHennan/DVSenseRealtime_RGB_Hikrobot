function packet = applyROI(packet,roi)
if ~roi.enabled || roi.mode == "hardware", return; end
r = roi.rectangle; x0=r(1); y0=r(2); x1=x0+r(3)-1; y1=y0+r(4)-1;
keep = double(packet.x)>=x0 & double(packet.x)<=x1 & ...
       double(packet.y)>=y0 & double(packet.y)<=y1;
packet.x = uint16(double(packet.x(keep))-x0+1);
packet.y = uint16(double(packet.y(keep))-y0+1);
packet.polarity = packet.polarity(keep);
packet.timestamp = packet.timestamp(keep);
packet.resolution = [r(4) r(3)];
packet.roiOffset = [x0-1 y0-1];
end

