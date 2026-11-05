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
 * Authors: J. Parker Jones
 */

#include "rtlCore.hh"

//#include "params/rtlObjectParams.hh"
#include "params/rtlCore.hh"
#include "sim/sim_events.hh"
#include "sim/sim_exit.hh"
#include "sim/stat_control.hh"
namespace gem5
{
////////////////////
// Memory Port Functions
////////////////////

void
rtlCore::IMemReqPort::recvReqRetry()
{
    bool success = sendTimingReq(owner->ipkt_stalled);
    if (success){
       busy=false;
    } 
}

bool
rtlCore::IMemReqPort::recvTimingResp(PacketPtr pkt)
{
    //can only handle one response per cycle
    if (pkt->req->getExtraData() == 0){
        if (!resp_busy){
            //if (true){
            if (pkt->req->taskId() == next_id)
            {
                if (owner->printireqs)
                {
                    printf("\n************ Received Response *************\n");
                    printf("ADDR: %X\n",pkt->getAddr());
                    printf("ID:  %X\n",pkt->req->taskId());
                    printf("%X\n\n",*pkt->getPtr<uint32_t>());
                }
                num_outstanding-=1;
                num_valid_outstanding-=1;
                owner->handleImemResp(pkt);

                next_id = !next_id; 
                resp_busy = true;
                busy=false;
                valid_out[pkt->req->taskId()]=false;
                return true;
            } else {
                // printf("\n+++++++++++ Stalled Response for ID Mismatch +++++++++++++\n");
                // printf("ADDR: %X\n",pkt->getAddr());
                // printf("ID:  %X\n",pkt->req->taskId());
                // printf("%X\n\n",*pkt->getPtr<uint32_t>());
                // printf("WAITING ON ID:  %X\n\n",next_id);
                resend_ooo_packet = true;
                ooo_packet = pkt;
                busy = true;
                uint32_t *data_ptr = pkt->getPtr<uint32_t>();

                ooo_val = *data_ptr;
                ooo_id = pkt->req->taskId();
                return true;
            }
            
        } else {
            // printf("\n&&&&&&&&& Stalled Response for Multiple in one cycle &&&&&&&&&&\n");
            // printf("ADDR: %X\n",pkt->getAddr());
            // printf("ID:  %X\n",pkt->req->taskId());
            // printf("%X\n\n",*pkt->getPtr<uint32_t>());
            resp_busy = true;
            send_respretry = true;
            busy=true;
            return false;
        }
    } else {
        if (owner->printireqs)
        {
            printf("-----Killed Packet-------\n");
            printf("%X\n",pkt->getAddr());
            printf("%X\n",*pkt->getPtr<uint32_t>());
            printf("ID:  %X\n\n",pkt->req->taskId());
        }
            busy=false;
            num_outstanding-=1;
            valid_out[pkt->req->taskId()]=false;
        return true; //packet has been killed. Ack
    }
}

void
rtlCore::DMemReqPort::recvReqRetry()
{
    //warn("Retry Signal Received - DMEM");
    bool success = sendTimingReq(owner->dpkt_stalled);
    if (success){
        //warn("Successful ReTransmission ##### DMEM");
            // warn("                ");
        //core->set_dport_gnt(true);
        
        //printf("%X\n",owner->dpkt_stalled->getAddr());
        //printf("%X\n",owner->dpkt_stalled->req->taskId());
        //printf("%X\n",owner->dpkt_stalled->req->time());
        //Allow only one outstanding dreq at once
        //busy=true;
        busy=false;
        prev_succ=true;
        //warn("Successful Re-Transmission ##### DMEM");
        //printf("%X\n",owner->dpkt_stalled->getAddr());
    } 
}
bool
rtlCore::DMemReqPort::recvTimingResp(PacketPtr pkt)
{
    if (owner->printdreqs)
    {
        warn("Successful Response ##### DMEM");
        printf("%X\n",pkt->getAddr());
    }
    //can only handle one response per cycle
    if (!resp_busy){
        owner->handleDmemResp(pkt);
        resp_busy = true;
        //
        busy=false;
        //
        return true;
    } else {
        resp_busy = true;
        send_respretry = true;
        //
        //busy=false;
        //
        return false;
    }
}



void
rtlCore::VMemReqPort::recvReqRetry()
{
    bool success = sendTimingReq(owner->vpkt_stalled);
    if (success){
       busy=false;
    } 
}
bool
rtlCore::VMemReqPort::recvTimingResp(PacketPtr pkt)
{
    //can only handle one response per cycle
    if (!resp_busy){
        if (true){ //Vector unit handles OoO responses in VLSU
        //if (pkt->req->taskId() == next_id)
        //{
            if (owner->printdreqs)
            {
                printf("\n************ Received Response VMEM *************\n");
                printf("ADDR: %X\n",pkt->getAddr());
                printf("ID:  %X\n",pkt->req->taskId());
                printf("%X\n\n",*pkt->getPtr<uint32_t>());
            }
            num_outstanding-=1;
            num_valid_outstanding-=1;
            owner->handleVmemResp(pkt);

            next_id = !next_id; 
            resp_busy = true;
            busy=false;
            valid_out[pkt->req->taskId()]=false;
            return true;
        } else {
            // printf("\n+++++++++++ Stalled Response for ID Mismatch +++++++++++++\n");
            // printf("ADDR: %X\n",pkt->getAddr());
            // printf("ID:  %X\n",pkt->req->taskId());
            // printf("%X\n\n",*pkt->getPtr<uint32_t>());
            // printf("WAITING ON ID:  %X\n\n",next_id);
            resend_ooo_packet = true;
            ooo_packet = pkt;
            busy = true;
            uint32_t *data_ptr = pkt->getPtr<uint32_t>();

            ooo_val = *data_ptr;
            ooo_id = pkt->req->taskId();
            return true;
        }
        
    } else {
        // printf("\n&&&&&&&&& Stalled Response for Multiple in one cycle &&&&&&&&&&\n");
        // printf("ADDR: %X\n",pkt->getAddr());
        // printf("ID:  %X\n",pkt->req->taskId());
        // printf("%X\n\n",*pkt->getPtr<uint32_t>());
        resp_busy = true;
        send_respretry = true;
        busy=true;
        return false;
    }
}

///////////////////////




///////////////////////
// RTL Core Constructor
rtlCore::rtlCore(const rtlCoreParams &params) :
    rtlObject(params),
    imem_req(params.name + ".imem_req", this),
    dmem_req(params.name + ".dmem_req", this),
    vmem_req(params.name + ".vmem_req", this),
    tracing(params.tracing),
    printdreqs(params.printdreqs),
    printireqs(params.printireqs),
    vmem_w(params.vmem_w)
{
    imem_req.busy=false;
    dmem_req.busy=false;
    vmem_req.busy=false;

    imem_req.resp_busy = false;
    imem_req.send_respretry = false;
    dmem_req.resp_busy = false;
    dmem_req.send_respretry = false;
    vmem_req.resp_busy = false;
    vmem_req.send_respretry = false;

    imem_req.num_outstanding = 0;
    imem_req.num_valid_outstanding=0;
    imem_req.num_flush = 0;
    imem_req.valid_out[0] = false;
    imem_req.valid_out[1] = false;
    imem_req.next_id = false;
    imem_req.resend_ooo_packet = false;
    imem_req.now_flush = false;
    imem_req.last_id_sent = false;

    vmem_req.num_outstanding = 0;
    vmem_req.num_valid_outstanding=0;
    vmem_req.num_flush = 0;
    vmem_req.valid_out[0] = false;
    vmem_req.valid_out[1] = false;
    vmem_req.next_id = false;
    vmem_req.resend_ooo_packet = false;
    vmem_req.now_flush = false;
    vmem_req.last_id_sent = false;

    initRTLModel();
}

// RTL Core Destructor
rtlCore::~rtlCore() {
    warn("calling destructor core");
    endRTLModel();
}

Port &
rtlCore::getPort(const std::string &if_name, PortID idx)
{
    if (if_name == "imem_req") {
        return imem_req;
    } else if (if_name == "dmem_req") {
        return dmem_req;
    } else if (if_name == "vmem_req") {
        return vmem_req;
    }else {
        panic_if(true, "Asking rtlCore for a port that doesnt exist");
        return ClockedObject::getPort(if_name, idx);
    }
}

void
rtlCore::initRTLModel() {
    // Init RTL Wrapper
    warn("Init RTLCORE");
    core = new Wrapper_Core(false, vmem_w, "trace.vcd");
    if (tracing){
        core->enableTracing(); //todo: disable tracing
    }
    core->set_dport_gnt(false);
    core->set_iport_gnt(false);
    core->set_vport_gnt(false);
    core->set_rst(false);
    core->tick_lo();
    core->tick_hi();
    core->tick_lo();
    warn("RST");
    core->set_rst(true);
    core->tick_lo();
    schedule(tickEvent,nextCycle());
}


// To be called when finishing the execution
// destroy RTL Model
void
rtlCore::endRTLModel() {
    warn("wrappper Destructor");
    delete core;
}

// To be called every tick
// advance RTL model simulation
void
rtlCore::tick() {


    //TODO: Put signal to change resolution of trace to reduce size
    core->advanceTickCount();
    core->top->eval();
    core->advanceTickCount();
    core->top->eval();
    core->tick_hi();

    core->set_dport_gnt(!dmem_req.busy);
    core->set_iport_gnt(!imem_req.busy);
    core->set_vport_gnt(!vmem_req.busy);


    //check for m5 control instructions on the xif interface
    core->signal_xif_result();
    Tick when = curTick();
    uint32_t m5_control_code;
    m5_control_code = core->check_xif_issue();
    switch(m5_control_code) {
        case 0x4200007B:
            printf("m5_exit called\n");
            exitSimLoop("SUCCESSFUL TERMINATION", 0, when, 0, true);
            break;
        case 0x4400007B: 
            printf("m5_fail called\n");
            exitSimLoop("OUTPUT MISMATCH", -1, when, 0, true);
            break;
        case 0x8000007B: //m5 reset stats
            printf("m5 reset stats called\n");
            gem5::statistics::schedStatEvent(false, true, when, 0);
            break;
        case 0x8200007B:
            printf("m5 dump stats called\n");
            gem5::statistics::schedStatEvent(true, false, when, 0);
            break;
        default:;
    }

    core->top->eval();

    core->advanceTickCount();
   
    dmem_req.prev_succ = false;
    //Handle D port req
    if (!dmem_req.busy){
        //warn("dmem open");
        if (core->get_dport_valid()){
            //warn("attempt DREQ");
            PacketPtr curReq = core->get_dport_packet();

            if (curReq->getAddr() == 0x400) //Don't send memory mapped accesses.  These cause segfaults in gem5
            {
                if (tracing){
                    core->enableTracing();
                }
                //printf("Cycles: %d\n", cyclesStat);
            }
            else {
                bool success = dmem_req.sendTimingReq(curReq);
                if (success){
                    if (printdreqs)
                    {
                        warn("Successful Transmission ##### DMEM");
                        printf("%X\n",curReq->getAddr());
                        printf("%X\n",curReq->req->taskId());
                        printf("Timestamp: %d\n",curReq->req->time());
                        warn("                ");
                    }

                    //Allow only one outstanding dreq at once
                    //
                    dmem_req.busy=true;
                    dmem_req.prev_succ=true;//Deprecated signal?
                    
                } else {
                    //warn("Failed DMEM Request, Retry #####");
                    //printf("%X\n",curReq->getAddr());
                    //printf("%X\n",curReq->req->taskId());
                    //printf("Timestamp: %d\n",curReq->req->time());
                    //warn("                ");
                    dpkt_stalled = curReq;
                    dmem_req.busy=true;
                }
            }
        }
    } else {
        //warn("dmem blocked");
    }

    //Handle V port req
    if (!vmem_req.busy){
        if (core->get_vport_valid()){

            vmem_req.num_outstanding+=1; //getting here always means a request is outstanding
            vmem_req.num_valid_outstanding+=1;
            if (vmem_req.num_outstanding == 2) //only 2 outstanding
            {
                vmem_req.busy=true;
            }

            PacketPtr curReq = core->get_vport_packet();

            bool success = vmem_req.sendTimingReq(curReq);
            if (success){
                if (printdreqs)
                {
                    warn("Successful Transmission ##### VMEM");
                    printf("%X\n",curReq->getAddr());
                    printf("%X\n",curReq->req->taskId());
                    printf("Timestamp: %d\n",curReq->req->time());
                    warn("                ");
                }

            } else {
                //warn("Failed VMEM Request, Retry #####");
                //printf("%X\n",curReq->getAddr());
                //printf("%X\n",curReq->req->taskId());
                //printf("Timestamp: %d\n",curReq->req->time());
                //warn("                ");
                vpkt_stalled = curReq;
                vmem_req.busy=true;
            }
        
        }
    } else {
        //warn("vmem blocked");
    }

    if (prevMemAddr ==  (uint32_t)core->top->mem_iaddr_o)
    {
        cyclesStalled+=1;
        if (cyclesStalled >= 10000){
            warn("Stalled for 10000 cycles at addr %X : %d cycles\n", prevMemAddr, cyclesStat);
            core->disableTracing();
            exitSimLoop("LOOP Encountered", -1, when, 0, true);
        }
    } else {
        cyclesStalled = 0;
    }
    prevMemAddr = (uint32_t)core->top->mem_iaddr_o;

    if (core->top->log_reg_w_o && cyclesStat >= 0){
        // printf("##### REGFILE WRITE #######");
        // printf("Cycle: %d\n", cyclesStat);
        // printf("Addr: %X\n",(uint32_t)core->top->log_reg_w_addr_o);
        // printf("Data: %X\n\n",(uint32_t)core->top->log_reg_w_data_o);

    }

    //Handle I Port req
    if (!imem_req.busy){
        if (core->get_iport_valid()){
            imem_req.num_outstanding+=1; //getting here always means a request is outstanding
            imem_req.num_valid_outstanding+=1;
            if (imem_req.num_outstanding == 2) //only 2 outstanding
            {
                imem_req.busy=true;
            }
            PacketPtr curReq = core->get_iport_packet();
            bool success = imem_req.sendTimingReq(curReq);

            imem_req.now_flush = false; //reset flush signal

            imem_req.outstanding[curReq->req->taskId()]=curReq;//put packet in outstanding requests buffer
            imem_req.valid_out[curReq->req->taskId()]=true;
            imem_req.last_id_sent=curReq->req->taskId();

            if (imem_req.num_valid_outstanding == 1)
            {
                imem_req.next_id = curReq->req->taskId(); //This is the intelligent way to do this.  TODO: Clean up other task ID checks
            }

            if (success){
                if (printireqs)
                {
                    warn("\n######## Successful I Transmission ######");
                    printf("%X\n",curReq->getAddr());
                    printf("ID:  %X\n\n",curReq->req->taskId());
                }
                if (curReq->getAddr() == 0x70)
                {
                    warn("Interrupt ADDRESS 70 REACHED ######");
                    core->disableTracing();
                    exitSimLoop("EXIT AT INTERRUPT VECTOR TABLE ACCESS", -1, when, 0, true);
                }
            } else {
                //warn("Failed I Transmission ######");
               //printf("%X\n\n\n",curReq->getAddr());
                ipkt_stalled = curReq;
                //core->set_iport_gnt(false);
                imem_req.busy=true;
            }
        }
    }else {
        //warn("imem blocked");
    }
    core->advanceTickCount();
    //Give status feedback
    if (cyclesStat % 10000 == 0)
    {
        printf("Current Cycles = %d\n Current PC = %X\n", cyclesStat, core->top->mem_iaddr_o);
    }

    core->tick_lo();
    core->top->eval();
    core->top->mem_irvalid_i = false;
    core->top->mem_rvalid_i = false;
    core->top->mem_wvalid_i = false;
    core->top->vec_mem_rvalid_i[0] = false;
    core->top->eval();
    cyclesStat++;
    stats.rtl_cycles++;
    schedule(tickEvent,nextCycle());

    //set mem port to allow new response and signal Dcache if request was blocked  MUST GO LAST as the call stack immediately calls response signal
    dmem_req.resp_busy = false;
    if (dmem_req.send_respretry)
    {
        //printf("Sending Retry Signal\n");
        dmem_req.send_respretry = false;
        dmem_req.sendRetryResp();
    }

    vmem_req.resp_busy = false;  //Vector unit should already be handling OoO responses 
    if (vmem_req.send_respretry)
    {
        //printf("Sending Retry Signal\n");
        vmem_req.send_respretry = false;
        vmem_req.sendRetryResp();
    }

    //Handle out of order responses on IMEM interface
    imem_req.resp_busy = false;
    if (imem_req.resend_ooo_packet && (imem_req.next_id == imem_req.ooo_id))
    {
        // printf("Put OOO packet in: \n");
        // printf("Data: %X \n", imem_req.ooo_val);
        // printf("ID: %X \n", imem_req.ooo_id);
        imem_req.resend_ooo_packet = false;
        imem_req.num_outstanding-=1;
        imem_req.num_valid_outstanding-=1;

        core->top->mem_irdata_i = imem_req.ooo_val;
        core->top->mem_irvalid_i = true;
        if (imem_req.ooo_id){
        core->top->mem_iid_i = true;
        }else{
        core->top->mem_iid_i = false;
        }

        imem_req.next_id = !imem_req.next_id; //is this condition sufficient?  Might need one from response interface TODO: This might be overwritten?
        imem_req.resp_busy = true;
        imem_req.busy=false;
        imem_req.valid_out[imem_req.ooo_id]=false;
            
    } else if (imem_req.send_respretry)
    {
        //printf("Sending Retry Signal\n");
        imem_req.send_respretry = false;
        imem_req.resend_ooo_packet = false;
        imem_req.sendRetryResp();
    }

}

bool
rtlCore::handleImemResp(PacketPtr pkt) {
     //warn("IMEM RESP");
     //printf("Cycles: %d", cyclesStat);
     //printf("%X\n",pkt->getAddr());
     //printf("%X\n",*pkt->getPtr<uint32_t>());
    core->set_imem_resp(pkt);
    core->top->eval();
    return true; //always accepts
}

bool
rtlCore::handleDmemResp(PacketPtr pkt) {
    //warn("Successful Response ##### DMEM");
    //printf("%X\n",pkt->getAddr());
    //printf("%X\n",pkt->req->taskId());
    //printf("Timestamp: %d\n",pkt->req->time());
    core->set_dmem_resp(pkt);
    return true; //always accepts
}

bool
rtlCore::handleVmemResp(PacketPtr pkt) {
    //warn("Successful Response ##### DMEM");
    //printf("%X\n",pkt->getAddr());
    //printf("%X\n",pkt->req->taskId());
    //printf("Timestamp: %d\n",pkt->req->time());
    core->set_vmem_resp(pkt);
    return true; //always accepts
}

} // namespace gem5
