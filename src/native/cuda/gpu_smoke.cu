#include "mex.h"
#include "gpu/mxGPUArray.h"

__global__ void timesTwo(const float* input,float* output,size_t n){
    size_t i=blockIdx.x*blockDim.x+threadIdx.x;
    if(i<n) output[i]=2.0f*input[i];
}

void mexFunction(int nlhs,mxArray* plhs[],int nrhs,const mxArray* prhs[]){
    if(nrhs!=1 || nlhs>1)
        mexErrMsgIdAndTxt("DVSense:CUDA","Usage: y = gpu_smoke(gpuArray(single(x)))");
    mxInitGPU();
    const mxGPUArray* in=mxGPUCreateFromMxArray(prhs[0]);
    if(mxGPUGetClassID(in)!=mxSINGLE_CLASS || mxGPUGetComplexity(in)!=mxREAL)
        mexErrMsgIdAndTxt("DVSense:CUDA","Input must be a real single gpuArray");
    const mwSize* dims=mxGPUGetDimensions(in);
    mwSize ndims=mxGPUGetNumberOfDimensions(in);
    mxGPUArray* out=mxGPUCreateGPUArray(ndims,dims,mxSINGLE_CLASS,mxREAL,MX_GPU_DO_NOT_INITIALIZE);
    size_t n=mxGPUGetNumberOfElements(in);
    const float* src=(const float*)mxGPUGetDataReadOnly(in);
    float* dst=(float*)mxGPUGetData(out);
    timesTwo<<<(unsigned int)((n+255)/256),256>>>(src,dst,n);
    plhs[0]=mxGPUCreateMxArrayOnGPU(out);
    mxGPUDestroyGPUArray(in); mxGPUDestroyGPUArray(out);
}

