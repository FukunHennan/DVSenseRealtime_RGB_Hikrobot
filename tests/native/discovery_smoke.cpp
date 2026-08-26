#include <chrono>
#include <iostream>
#include <iomanip>
#include "DvsenseDriver/camera/DvsCameraManager.hpp"

int main() {
    try {
        dvsense::DvsCameraManager manager;
        const auto start=std::chrono::steady_clock::now();
        const auto devices=manager.getCameraDescs();
        const auto elapsed=std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now()-start).count();
        std::cout<<"getCameraDescs count="<<devices.size()
                 <<" elapsed_ms="<<elapsed<<"\n";

        std::string fusionSerial;
        for (size_t index = 0; index < devices.size(); ++index) {
            const auto& device = devices[index];
            std::cout<<"camera["<<index<<"]"
                     <<" product="<<device.product
                     <<" serial="<<device.serial
                     <<" manufacturer="<<device.manufacturer
                     <<" vid=0x"<<std::hex<<std::setw(4)<<std::setfill('0')
                     <<device.vid
                     <<" pid=0x"<<std::setw(4)<<device.pid
                     <<std::dec<<std::setfill(' ')
                     <<" interfaceType="<<static_cast<int>(device.interfaceType)
                     <<"\n";
            if (device.product == "DVSync" && !device.serial.empty()) {
                fusionSerial = device.serial;
            }
        }

        if (fusionSerial.empty()) {
            std::cerr<<"sync_path_error=no_DVSync_with_nonempty_serial\n";
            return 4;
        }

        auto fusionCamera = manager.openFusionCamera(fusionSerial);
        if (!fusionCamera) {
            std::cerr<<"sync_path_error=openFusionCamera_returned_null"
                     <<" serial="<<fusionSerial<<"\n";
            return 5;
        }
        std::cout<<"fusion_open serial="<<fusionSerial
                 <<" connected="<<(fusionCamera->isConnected() ? "true" : "false")
                 <<"\n";
        if (!fusionCamera->isConnected()) {
            std::cerr<<"sync_path_error=fusion_camera_not_connected\n";
            return 6;
        }

        return 0;
    } catch(const std::exception& error) {
        std::cerr<<"discovery_error="<<error.what()<<"\n";
        return 2;
    }
}
