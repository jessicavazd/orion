package orion_soc_types;
    // parameter SOC_IMEM_SIZE = 32*1024;   // 32KB
    // parameter SOC_DMEM_SIZE = 32*1024;   // 32KB  

    parameter SOC_MEM_BASE_ADDR = 32'h0001_0000;
    parameter SOC_MEM_SIZE = 16*1024;       // 16KB

    parameter SOC_UART_BASE_ADDR = 32'h1000_0000;
    parameter SOC_UART_SIZE  = 16;

    parameter SOC_RESET_ADDR = SOC_MEM_BASE_ADDR;

    parameter WBADDRW = ADDRW;      // Inherit from orion_types
    parameter WBDATAW = DATAW;      // Inherit from orion_types
    parameter WBSELW  = MASKW;      // Inherit from orion_types
endpackage
