function available = gpuAvailable()
available = false;
try
    available = license("test","Distrib_Computing_Toolbox") && canUseGPU;
catch
    available = false;
end
end
