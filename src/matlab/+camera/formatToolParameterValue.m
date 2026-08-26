function valueText = formatToolParameterValue(value,type)
arguments
    value
    type
end

switch upper(string(type))
    case "BOOL"
        if islogical(value) && isscalar(value)
            valueText = char(string(value));
        elseif isnumeric(value) && isscalar(value)
            valueText = char(string(logical(value)));
        else
            valueText = char(string(value));
        end
    otherwise
        valueText = char(string(value));
end
end
