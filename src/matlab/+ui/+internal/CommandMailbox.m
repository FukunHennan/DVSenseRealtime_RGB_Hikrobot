classdef CommandMailbox < handle
    properties (Access = private)
        Capacity (1,1) double {mustBeInteger,mustBePositive} = 64
        Items cell = {}
    end

    methods
        function obj = CommandMailbox(capacity)
            arguments
                capacity (1,1) double {mustBeInteger,mustBePositive} = 64
            end
            obj.Capacity = capacity;
        end

        function push(obj, command)
            arguments
                obj
                command (1,1) struct
            end
            if ~isfield(command,"type")
                error("DVSense:InvalidCommand","命令缺少type字段。");
            end

            key = obj.coalescingKey(command);
            if strlength(key) > 0
                for index = 1:numel(obj.Items)
                    if obj.coalescingKey(obj.Items{index}) == key
                        obj.Items{index} = command;
                        return
                    end
                end
            end

            if numel(obj.Items) >= obj.Capacity
                error("DVSense:CommandMailboxFull", ...
                    "界面命令队列已满，未丢弃受保护命令。");
            end
            obj.Items{end+1} = command;
        end

        function commands = consume(obj)
            commands = obj.Items;
            obj.Items = {};
        end

        function clear(obj)
            obj.Items = {};
        end

        function count = count(obj)
            count = numel(obj.Items);
        end
    end

    methods (Access = private)
        function key = coalescingKey(~, command)
            type = string(command.type);
            switch type
                case "setDisplayAccumulationUs"
                    key = "setDisplayAccumulationUs";
                case "setRgbExposureUs"
                    key = "setRgbExposureUs";
                case "setRgbThreshold"
                    key = "setRgbThreshold";
                case "setToolParameter"
                    if isfield(command,"tool") && isfield(command,"name")
                        key = "setToolParameter/" + string(command.tool) + ...
                            "/" + string(command.name);
                    else
                        key = "";
                    end
                otherwise
                    key = "";
            end
        end
    end
end
