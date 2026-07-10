#pragma once

class Simulator
{
    private:

    public:

    Simulator(){};

    //Function to start measurement
    //Verilator Simulation uses simulated CSRs
    inline void begin_measurement()
    {

    };

    //Function to end measurement
    //Verilator Simulation uses simulated CSRs
    inline void end_measurement()
    {

    };

    //Termination success or failure function for this simulator
    void terminate(int code) // TODO: Int return codes
    {

    };

    //Cleanup any allocatations
    ~Simulator(){};
};
