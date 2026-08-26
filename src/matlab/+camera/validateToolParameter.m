function value=validateToolParameter(parameter,value)
arguments
    parameter (1,1) struct
    value
end

type=upper(string(parameter.type));
switch type
    case "INT"
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
                value==fix(value))
            error("DVSense:InvalidParameterValue","整数参数必须是有限标量。");
        end
        value=double(value);
        checkRange(parameter,value);
    case "FLOAT"
        if ~(isnumeric(value) && isscalar(value) && isfinite(value))
            error("DVSense:InvalidParameterValue","浮点参数必须是有限标量。");
        end
        value=double(value);
        checkRange(parameter,value);
    case "BOOL"
        if islogical(value) && isscalar(value)
            value=logical(value);
        elseif (ischar(value) || (isstring(value) && isscalar(value))) && ...
                any(strcmpi(string(value),["true","false"]))
            value=strcmpi(string(value),"true");
        else
            error("DVSense:InvalidParameterValue","布尔参数只能是true或false。");
        end
    case "ENUM"
        value=string(value);
        if ~isscalar(value) || ~isfield(parameter,"options") || ...
                ~any(strcmp(value,string(parameter.options)))
            error("DVSense:InvalidParameterOption","参数值不在SDK返回的枚举选项中。");
        end
    case "STRING"
        value=string(value);
        if ~isscalar(value)
            error("DVSense:InvalidParameterValue","字符串参数必须是标量文本。");
        end
    otherwise
        error("DVSense:UnsupportedParameterType","SDK返回了未支持的参数类型：%s",type);
end
end

function checkRange(parameter,value)
minimum=metadataNumber(parameter,"min");
maximum=metadataNumber(parameter,"max");
if isfinite(minimum) && isfinite(maximum) && ...
        (value<minimum || value>maximum)
    error("DVSense:ParameterOutOfRange", ...
        "参数值必须在[%g,%g]范围内。",minimum,maximum);
end
end

function number=metadataNumber(parameter,field)
number=NaN;
if ~isfield(parameter,field) || isempty(parameter.(field)), return; end
raw=parameter.(field);
if isnumeric(raw) && isscalar(raw)
    number=double(raw);
else
    number=str2double(string(raw));
end
end
