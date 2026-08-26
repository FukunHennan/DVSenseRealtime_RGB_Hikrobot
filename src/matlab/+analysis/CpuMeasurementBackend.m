classdef CpuMeasurementBackend < analysis.MeasurementBackend
    properties
        Name string = "cpu"
    end
    properties (Access=private)
        RenderFrame uint8 = uint8.empty
        RenderResolution double = [0 0]
    end
    methods
        function m = extractMeasurement(~,packet,cfg)
            n = numel(packet.x);
            m = struct("valid",false,"position",[NaN;NaN], ...
                "boundingBox",[NaN NaN NaN NaN],"confidence",0);
            if n < cfg.tracking.minimumEvents, return; end
            x=double(packet.x);
            y=double(packet.y);
            trimFraction=0;
            if isfield(cfg.tracking,"trimFraction")
                trimFraction=max(0,min(0.2,double(cfg.tracking.trimFraction)));
            end
            if trimFraction>0 && n>=20
                trimCount=floor(n*trimFraction);
                sortedX=sort(x);
                sortedY=sort(y);
                keep=x>=sortedX(trimCount+1) & x<=sortedX(n-trimCount) & ...
                    y>=sortedY(trimCount+1) & y<=sortedY(n-trimCount);
                if nnz(keep)>=cfg.tracking.minimumEvents
                    x=x(keep);
                    y=y(keep);
                end
            end
            xmin=double(min(x)); xmax=double(max(x));
            ymin=double(min(y)); ymax=double(max(y));
            m.valid=true; m.position=[mean(x);mean(y)];
            m.boundingBox=[xmin ymin xmax-xmin+1 ymax-ymin+1];
            m.confidence=min(1,numel(x)/max(cfg.source.eventsPerWindow,1));
        end
        function frame = render(obj,packet,cfg)
            if isfield(cfg.display,"scale")
                scale=max(0.1,min(1,double(cfg.display.scale)));
            else
                scale=1;
            end
            h=max(1,round(packet.resolution(1)*scale));
            w=max(1,round(packet.resolution(2)*scale));
            if isempty(obj.RenderFrame) || any(obj.RenderResolution~=[h w])
                obj.RenderFrame=ones(h,w,"uint8");
                obj.RenderResolution=[h w];
            else
                obj.RenderFrame(:)=uint8(1);
            end
            frame=obj.RenderFrame;
            if isempty(packet.x), return; end
            x=round(double(packet.x)*scale);
            y=round(double(packet.y)*scale);
            valid=x>=1 & x<=w & y>=1 & y<=h;
            x=x(valid); y=y(valid); p=packet.polarity(valid);
            idx=sub2ind([h w],y,x);
            obj.RenderFrame(idx(p))=uint8(2);
            obj.RenderFrame(idx(~p))=uint8(3);
            frame=obj.RenderFrame;
        end
    end
end
