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

#include "wrapper_core.hh"

Wrapper_Core::Wrapper_Core(bool traceOn, int mem_w, std::string name) :
        tickcount(0),
        fst(NULL),
        fstname(name),
        traceOn(traceOn) {
    
    vmem_w = mem_w;
    top = new Vvproc_top;

    Verilated::traceEverOn(true);
    fst = new VerilatedVcdC;
    if (!fst) {
        return;
    }
    
    // fst, levels, options
    top->trace(fst,99);

    std::cout << fstname << std::endl;
    fst->open(fstname.c_str());

    top->mem_ierr_i = false;
    top->mem_err_i = false;
    top->vec_mem_err_i[0] = false;
    top->mem_ignt_i = false;
    top->mem_gnt_i = false;
    top->vec_mem_gnt_i[0] = false;
    killOutstanding = false;

}

Wrapper_Core::~Wrapper_Core() {
    if (fst) {
        fst->dump(tickcount);
        fst->close();
        delete fst;
    }
    //top->final();
    delete top;
    
    exit(EXIT_SUCCESS);
}

void Wrapper_Core::enableTracing() {
    traceOn = true;
}

void Wrapper_Core::disableTracing() {
    traceOn = false;
    fst->dump(tickcount);
    fst->close();
}

void Wrapper_Core::tick_hi() {

    top->clk_i = 1;
    top->eval();

    advanceTickCount();
}
void Wrapper_Core::tick_lo() {

    top->clk_i = 0;
    top->eval();

    advanceTickCount();
}

void Wrapper_Core::advanceTickCount() {
    if (fst and traceOn) {
        fst->dump(tickcount);
    }
    tickcount++;
}

uint64_t Wrapper_Core::getTickCount() {
    return tickcount;
}

void Wrapper_Core::set_rst(bool val){
    //top->clk_i = 1;
    top->eval();
    advanceTickCount();
    top->rst_ni = val;
    //top->clk_i = 0;
    top->eval();
    advanceTickCount();
}

/// IMEM PORT
bool Wrapper_Core::get_iport_valid(){
    return (bool)top->mem_ireq_o;
}
 
gem5::PacketPtr Wrapper_Core::get_iport_packet(){
    uint32_t addr = (uint32_t)top->mem_iaddr_o;

    gem5::RequestPtr req = std::make_shared<gem5::Request>(addr, 4, gem5::Request::INST_FETCH, 0);
    req->taskId((uint32_t)top->mem_iid_o);
    gem5::PacketPtr packet = nullptr;
    req->setExtraData(0);//haven't killed Request
    packet = gem5::Packet::createRead(req); //always a read request
    packet->allocate();
    return packet;
}

void Wrapper_Core::set_iport_gnt(bool val){
    top->mem_ignt_i = val & top->mem_ireq_o;
}
void Wrapper_Core::set_imem_resp(gem5::PacketPtr pkt){
    uint32_t *data_ptr = pkt->getPtr<uint32_t>();

    if (!killOutstanding){
        top->mem_irdata_i = *data_ptr;
        top->mem_irvalid_i = true;
        if (pkt->req->taskId()){
        top->mem_iid_i = true;
        }else{
        top->mem_iid_i = false;
        }
    } else {
        killOutstanding = false;
    }

}

/// DMEM PORT
bool Wrapper_Core::get_dport_valid(){
    return (bool)top->mem_req_o;
}
 
gem5::PacketPtr Wrapper_Core::get_dport_packet(){
    uint32_t addr = (uint32_t)top->mem_addr_o & 0xFFFFFFFC;
    //uint32_t addr = (uint32_t)top->mem_addr_o;

  
    if (top->mem_we_o){
        //printf("\n\nWrite Packet\n");
        //printf("Data %X\n", top->mem_wdata_o);
        gem5::RequestPtr req = std::make_shared<gem5::Request>(addr, 4, gem5::Request::STRICT_ORDER, 0); //This port is always 32 bits wide
        req->taskId((bool)top->mem_id_o);
        gem5::PacketPtr packet = nullptr;
        //warn("Creating WRITE Packet");
        req->setExtraData((uint32_t)top->mem_src_o);
        packet = gem5::Packet::createWrite(req);
        //uint32_t* dataPtr = (uint32_t*)(&top->mem_wdata_o);
        uint32_t* dataPtr = (uint32_t*)malloc(4);
        memcpy(dataPtr, &(top->mem_wdata_o), 4);
        packet->dataDynamic((uint8_t*)dataPtr);
        std::vector<bool> be = {(bool)(((uint8_t)top->mem_be_o)& 1), (bool)(((uint8_t)top->mem_be_o >> 1)& 1), (bool)(((uint8_t)top->mem_be_o >> 2)& 1), (bool)(((uint8_t)top->mem_be_o >> 3)& 1)};

        req->setByteEnable(be);
        //packet->dataStatic(dataPtr); //need free()
        //warn("Done");
        if (addr == 0x400)
        {
            printf("%c", top->mem_wdata_o); //print any writes to 0x400 as uart
        }
        if (addr == 0x404)
        {
            printf("%d", top->mem_wdata_o); //print any writes to 0x404 as uart
        }
        if (packet->needsResponse())
        {
            //warn("Needs Response");
        }
        return packet;
        
    } else {
        //warn("Creating READ Packet");
        gem5::RequestPtr req = std::make_shared<gem5::Request>(addr, 4, gem5::Request::INST_FETCH, 0); //for some reason, trying to set reads the other way fails to read data correctly.
        req->setExtraData((uint32_t)top->mem_src_o);
        req->taskId((uint32_t)top->mem_id_o);
        //std::vector<bool> be = {(bool)(((uint8_t)top->mem_be_o >> 3)& 1), (bool)(((uint8_t)top->mem_be_o >> 2)& 1), (bool)(((uint8_t)top->mem_be_o >> 1)& 1), (bool)(((uint8_t)top->mem_be_o)& 1)};
        //req->setByteEnable(be);
        gem5::PacketPtr packet = nullptr;
        packet = gem5::Packet::createRead(req); //always a read request
        packet->allocate();
        //packet = gem5::Packet::createRead(req);
        //uint8_t* dataPtr = (uint8_t*)(&top->mem_wdata_o);//thsi data shouldnt matter, just defining the variable to set data static
        //packet->dataStatic(dataPtr); 
        return packet;
    }
}

void Wrapper_Core::set_dport_gnt(bool val){
    top->mem_gnt_i = val & top->mem_req_o; //scalar port is a "grant" port, and should only be high if a request is being issued
    //top->mem_vec_gnt_i = val;
}
void Wrapper_Core::set_dmem_resp(gem5::PacketPtr pkt){
    uint32_t *data_ptr = pkt->getPtr<uint32_t>();

    top->mem_rdata_i = *data_ptr;

    if (pkt->isWrite()){

        if (pkt->req->getExtraData() == 0)
        {
            //scalar Write Response
            top->mem_src_i = false;
            top->mem_wvalid_i = true;
            top->mem_id_i = pkt->req->taskId();
            free(pkt->getPtr<uint32_t>());
        } else {
            //Vector Write Response
            top->mem_src_i = true;
            top->mem_rvalid_i = true;
            free(pkt->getPtr<uint32_t>());
        }
    }else{
        //printf("\n\nValid Data Response Packet\n");
        top->mem_rvalid_i = true;
        if (pkt->req->getExtraData() == 0)
        {  
            //Scalar Read Response
            top->mem_src_i = false;
            top->mem_id_i = pkt->req->taskId();
            //printf("\n\nData Response Packet\n");
            //printf("Data %X\n", *data_ptr);
        } else {
            //Vector Read Response
            top->mem_src_i = true;
        }
    }
}

/// VMEM PORT
bool Wrapper_Core::get_vport_valid(){
    return (bool)top->vec_mem_req_o[0];
}
 
gem5::PacketPtr Wrapper_Core::get_vport_packet(){
    uint32_t addr = (uint32_t)top->vec_mem_addr_o[0] & 0xFFFFFFFC;

    if (top->vec_mem_we_o[0]){
        gem5::RequestPtr req = std::make_shared<gem5::Request>(addr, vmem_w/8, gem5::Request::STRICT_ORDER, 0);
        req->taskId((bool)top->vec_mem_id_o[0]); //Currently only two valid Ids, so 2 oustanding requests
        gem5::PacketPtr packet = nullptr;
        packet = gem5::Packet::createWrite(req);
        uint32_t* dataPtr = (uint32_t*)malloc(vmem_w/8);
        memcpy(dataPtr, &(top->vec_mem_wdata_o[0]), vmem_w/8);
        packet->dataDynamic((uint8_t*)dataPtr);
        std::vector<bool> be = {};
        for (int i = 0; i < vmem_w/8; i++)
        {
            be.push_back((bool)(((uint8_t)top->vec_mem_be_o[0] >> i)& 1));
        }
        req->setByteEnable(be);
        return packet;
    } else {
        gem5::RequestPtr req = std::make_shared<gem5::Request>(addr, vmem_w/8, gem5::Request::INST_FETCH, 0); //for some reason, trying to set reads the other way fails to read data correctly.
        gem5::PacketPtr packet = nullptr;
        req->taskId((bool)top->vec_mem_id_o[0]);
        packet = gem5::Packet::createRead(req); //always a read request
        packet->allocate();
        return packet;
    }
}
void Wrapper_Core::set_vport_gnt(bool val){
    top->vec_mem_gnt_i[0] = val & top->vec_mem_req_o[0];
}
void Wrapper_Core::set_vmem_resp(gem5::PacketPtr pkt){
    uint32_t *data_ptr = pkt->getPtr<uint32_t>();
    memcpy(&(top->vec_mem_rdata_i[0]), data_ptr, vmem_w/8);
    top->vec_mem_id_i[0] = pkt->req->taskId();
    if (pkt->isWrite()){
        //Vector Write Response
        top->vec_mem_src_i = true;
        top->vec_mem_rvalid_i[0] = true;
        free(pkt->getPtr<uint32_t>());
    }else{
        //printf("\n\nValid Data Response Packet\n");
        top->vec_mem_rvalid_i[0] = true;
        top->vec_mem_src_i = true;
    }
}

uint32_t Wrapper_Core::check_xif_issue(){
    uint32_t instr = 0;
    top->xif_issue_accept_i = false;
    xif_signal_result[0] = false;

    if (top->xif_issue_valid_o) {
        instr = (uint32_t)top->xif_issue_instr_o;
        switch (instr){
            case 0x4200007B: //m5 exit
                xif_signal_result[0] = true;
                top->xif_issue_accept_i = true;
                top->xif_result_id_i = top->xif_issue_id_o;
                break;
            case 0x4400007B: //m5 fail
                xif_signal_result[0] = true;
                top->xif_issue_accept_i = true;
                top->xif_result_id_i = top->xif_issue_id_o;
                break;
            case 0x8000007B: //m5 reset stats
                xif_signal_result[0] = true;
                top->xif_issue_accept_i = true;
                top->xif_result_id_i = top->xif_issue_id_o;
                break;
            case 0x8200007B:
                xif_signal_result[0] = true;
                top->xif_issue_accept_i = true;
                top->xif_result_id_i = top->xif_issue_id_o;
                break;
        }
    }
    return instr;
}

void Wrapper_Core::signal_xif_result(){
    top->xif_result_valid_i = false;
    if (xif_signal_result[1]) {
        if (top->xif_result_ready_o) {
            top->xif_result_valid_i = true;
        }
    }
    xif_signal_result[1] = xif_signal_result[0]; //Advance buffer
}


