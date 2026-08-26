function parameters=applyToolParameterReadback( ...
    parameters,toolName,parameterName,current)
arguments
    parameters struct
    toolName (1,1) string
    parameterName (1,1) string
    current
end

matches=strcmp(string({parameters.tool}),toolName) & ...
    strcmp(string({parameters.name}),parameterName);
if nnz(matches)~=1
    error("DVSense:ParameterNotFound", ...
        "未找到唯一的SDK参数：%s/%s",toolName,parameterName);
end
parameters(matches).current=char(string(current));
end
