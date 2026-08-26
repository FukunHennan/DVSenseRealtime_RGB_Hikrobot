function [stopRequested,displayAccumulationUs,startRequested]=readViewerCommandState(commands,currentAccumulationUs)
arguments
    commands cell
    currentAccumulationUs (1,1) double
end

stopRequested=false;
startRequested=false;
displayAccumulationUs=max(1000,min(100000,round(double(currentAccumulationUs))));
for commandIndex=1:numel(commands)
    command=commands{commandIndex};
    switch string(command.type)
        case "stop"
            stopRequested=true;
        case "start"
            startRequested=true;
        case "setDisplayAccumulationUs"
            displayAccumulationUs=max(1000,min(100000, ...
                round(double(command.value))));
    end
end
end
