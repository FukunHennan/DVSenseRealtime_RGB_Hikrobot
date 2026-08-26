function serial=selectCameraSerial(devices,preferredSerial)
arguments
    devices struct
    preferredSerial (1,1) string = ""
end

if isempty(devices)
    error("DVSense:NoCamera","未发现可用的DVSense相机。");
end

serials=string({devices.serial});
preferredSerial=string(preferredSerial);
if strlength(preferredSerial)>0
    match=find(serials==preferredSerial,1);
    if isempty(match)
        if numel(serials)==1
            serial=serials(1);
            return
        end
        error("DVSense:CameraSelectionRequired", ...
            "配置的序列号 %s 不在当前发现的相机列表中。",preferredSerial);
    end
    serial=serials(match);
    return
end

if numel(serials)==1
    serial=serials(1);
    return
end

error("DVSense:CameraSelectionRequired", ...
    "当前发现了 %d 台相机，需要用户选择序列号。",numel(serials));
end
