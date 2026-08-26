classdef RuntimeLayout
    % Resolve the private native runtime without changing the user PATH.
    properties (SetAccess = private)
        Root string
        BridgeLibrary string
        VendorLibraries string
    end

    methods
        function obj = RuntimeLayout(projectRoot)
            arguments
                projectRoot string = string(localProjectRoot())
            end

            obj.Root = fullfile(projectRoot, "runtime", "bin");
            if ~isfolder(obj.Root) && isfolder(fullfile(projectRoot, "runtime"))
                obj.Root = fullfile(projectRoot, "runtime");
            end
            obj.BridgeLibrary = fullfile(obj.Root, "dvsense_bridge.dll");
            runtimeFiles = dir(fullfile(obj.Root, "*.dll"));
            names = string({runtimeFiles.name});
            names = names(names ~= "dvsense_bridge.dll");
            obj.VendorLibraries = fullfile(obj.Root, names);
        end

        function cleanup = addToPath(obj)
            originalPath = path;
            if isfolder(obj.Root)
                addpath(obj.Root, "-begin");
            end
            cleanup = onCleanup(@()path(originalPath));
        end
    end
end

function root = localProjectRoot()
root = fileparts(mfilename("fullpath"));
while strlength(root) > 0
    if isfile(fullfile(root,"VERSION")) && isfile(fullfile(root,"main.m"))
        return
    end
    parent = fileparts(root);
    if strcmp(parent,root)
        break
    end
    root = parent;
end
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
end
