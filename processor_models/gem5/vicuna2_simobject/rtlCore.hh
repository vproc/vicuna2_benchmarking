/*
 * Copyright (c) 2026 Jefferson Parker Jones TUWien
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met: redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer;
 * redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution;
 * neither the name of the copyright holders nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Authors: Jefferson Parker Jones
 */

#ifndef __RTL_CORE_VERILATOR_HH__
#define __RTL_CORE_VERILATOR_HH__

#include <queue>
#include <string>
#include <vector>

#include "cpu/base.hh"
#include "cpu/translation.hh"
#include "debug/rtlCore.hh"
//#include "debug/rtlCoreDebug.hh"
#include "rtlObject.hh"
#include "sim/system.hh"
#include "wrapper_core.hh"

namespace gem5
{
struct rtlCoreParams;
/**
 * A very simple memory object. Current implementation doesn't even cache
 * anything it just forwards requests and responses.
 * This memobj is fully blocking (not non-blocking). Only a single request can
 * be outstanding at a time.
 */
class rtlCore : public rtlObject
{
  private:

    ///////////////////////////
    // Memory Port classes
    ///////////////////////////

    class IMemReqPort : public RequestPort
    {
      private:
        rtlCore *owner;

      public:
        IMemReqPort(const std::string& name, rtlCore *owner) :
            RequestPort(name, owner), owner(owner)
        { }
      bool busy;
      bool resp_busy;
      bool send_respretry;
      int num_outstanding;
      int num_valid_outstanding;
      int num_flush;
      PacketPtr outstanding[2];
      bool valid_out[2];

      bool next_id;
      bool resend_ooo_packet;
      bool ooo_packet_valid;
      PacketPtr ooo_packet;
      uint32_t ooo_val;
      bool ooo_id;
      bool now_flush;

      bool last_id_sent;

      protected:
        bool recvTimingResp(PacketPtr pkt) override;
        void recvReqRetry() override;
        //void recvRangeChange() override;
    };

    class DMemReqPort : public RequestPort
    {
      private:
        rtlCore *owner;

      public:
        DMemReqPort(const std::string& name, rtlCore *owner) :
            RequestPort(name, owner), owner(owner)
        { }
        bool busy;
        bool prev_succ;
        bool resp_busy;
        bool send_respretry;

      protected:
        bool recvTimingResp(PacketPtr pkt) override;
        void recvReqRetry() override;
        //void recvRangeChange() override;
    };

    class VMemReqPort : public RequestPort
    {
      private:
        rtlCore *owner;

      public:
        VMemReqPort(const std::string& name, rtlCore *owner) :
            RequestPort(name, owner), owner(owner)
        { }
      bool busy;
      bool resp_busy;
      bool send_respretry;
      int num_outstanding;
      int num_valid_outstanding;
      int num_flush;
      PacketPtr outstanding[2];
      bool valid_out[2];

      bool next_id;
      bool resend_ooo_packet;
      bool ooo_packet_valid;
      PacketPtr ooo_packet;
      uint32_t ooo_val;
      bool ooo_id;
      bool now_flush;

      bool last_id_sent;

      protected:
        bool recvTimingResp(PacketPtr pkt) override;
        void recvReqRetry() override;
        //void recvRangeChange() override;
    };
    ////////////////////////////////////////
    // Port instantiations - Core is initiator so all are request ports
    ////////////////////////////////////////
    IMemReqPort imem_req;

    DMemReqPort dmem_req;

    VMemReqPort vmem_req;

    ////////////////////////////////////////
    // Internal Helper Functions
    ////////////////////////////////////////

    bool handleImemResp(PacketPtr pkt);
    bool handleDmemResp(PacketPtr pkt);
    bool handleVmemResp(PacketPtr pkt);


    PacketPtr vpkt_stalled;
    PacketPtr dpkt_stalled;
    PacketPtr ipkt_stalled;

    uint32_t prevMemAddr;

    uint32_t cyclesStalled;
    uint32_t prev_addr;

    bool tracing;
    bool printdreqs;
    bool printireqs;
    int  vmem_w;


public:

    // wrapper pointer
    Wrapper_Core *core;

    // Constructor
    rtlCore(const rtlCoreParams &params);

    // Destructor
    ~rtlCore();

    gem5::Port &getPort(const std::string &if_name,
                  PortID idx=InvalidPortID) override;

    // To be called when starting the rtl Object
    void initRTLModel() override;
    // To be called when finishing the execution
    void endRTLModel() override;
    // To be called every tick()
    void tick() override;

};





} //End namespace gem5


#endif // __ACCELERATOR_VERILATOR_HH__
