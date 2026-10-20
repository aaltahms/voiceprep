#include "../src/Realtime.hpp"
#include <chrono>
#include <iostream>
#include <cstdlib>
#include <new>
static bool forbidAllocation=false;
void* operator new(std::size_t size){if(forbidAllocation){std::cerr<<"render allocated\n";std::abort();}if(auto p=std::malloc(size))return p;throw std::bad_alloc();}
void operator delete(void* p)noexcept{std::free(p);}
void* operator new[](std::size_t size){return ::operator new(size);}
void operator delete[](void* p)noexcept{std::free(p);}
int main(){vp::RealtimeProcessor p(192000,2);float input[128],output[128];for(int i=0;i<128;i++)input[i]=float(.6*std::sin(i*.13));double worst=0,total=0;for(int b=0;b<20000;b++){if(b%16==0)p.setSettings({double(b%181),double(b%101)/100,double(b%25)-12});auto begin=std::chrono::steady_clock::now();forbidAllocation=true;p.process(input,output,64);forbidAllocation=false;double us=std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-begin).count();worst=std::max(worst,us);total+=us;}std::cout<<"192kHz stereo, 64 frames: mean "<<total/20000<<" us, worst "<<worst<<" us; buffer budget 333.33 us; no C++ heap allocations\n";}
