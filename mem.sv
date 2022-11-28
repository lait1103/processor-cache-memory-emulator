`include "constants.sv"

module mem  #(parameter _SEED = 225526) (input clk, input M_DUMP, input RESET, inout wire [`DATA2_BUS_SIZE - 1 : 0] d2, inout wire [`CTR2_BUS_SIZE - 1 : 0] c2, input wire [`ADDR2_BUS_SIZE - 1 : 0] a2);
  integer SEED = _SEED;
  logic [`BITS_IN_BYTE - 1 : 0] memLines[`MEM_SIZE - 1 : 0];

  reg [`DATA2_BUS_SIZE - 1 : 0] mem_d2 = 'z;
  reg [`CTR2_BUS_SIZE - 1 : 0]  mem_c2 = 'z;
  assign d2 = mem_d2;
  assign c2 = mem_c2;

  bit [`ADDR2_BUS_SIZE - 1 : 0] readedSetTag;

  initial begin 
      for (int i = 0; i < `MEM_SIZE; i += 1) begin
          memLines[i] = $random(SEED)>>16;  
      end
  end

  integer i = 0;

  always @(negedge clk) begin
      if(c2 == `C2_READ_LINE) begin
         $fdisplay(counter.log, "Mem got C2_READ_LINE request, time = %0d", $time / 2); 
        readedSetTag = a2;
        `delay(1, 0)

        mem_c2 = `C2_NOP;
        `delay(`MEM_CTR_WAIT * 2 - 2, 1)

        mem_c2 = `C2_RESPONSE;
        for(i = 0; i < `SEND_FROM_MEM; i++) begin
            mem_d2[`BITS_IN_BYTE - 1 : 0] =               memLines[readedSetTag * (1 << `CACHE_OFFSET_SIZE) + 2 * i];
            mem_d2[`DATA2_BUS_SIZE - 1 : `BITS_IN_BYTE] = memLines[readedSetTag * (1 << `CACHE_OFFSET_SIZE) + 2 * i + 1];
            `delay(2, 1)
        end
        mem_c2 = 'z;
        mem_d2 = 'z;
      end else if(c2 == `C2_WRITE_LINE) begin  
        $fdisplay(counter.log, "Mem got C2_WRITE_LINE request, time = %0d", $time / 2); 
        readedSetTag = a2;
        for(i = 0; i < `SEND_FROM_MEM; i++) begin
            memLines[readedSetTag * (1 << `CACHE_OFFSET_SIZE) + 2 * i] = d2[`BITS_IN_BYTE - 1 : 0];
            memLines[readedSetTag * (1 << `CACHE_OFFSET_SIZE) + 2 * i + 1] = d2[`DATA2_BUS_SIZE - 1 : `BITS_IN_BYTE];
            `delay(2, 0)
        end
       `delay(`MEM_CTR_WAIT * 2 - `SEND_FROM_MEM * 2 - 3, 0)
        mem_c2 = `C2_RESPONSE;
        $fdisplay(counter.log, "Mem send C2_RESPONSE respoce after reading, time = %0d", $time / 2); 
        `delay(2, 1)
        mem_c2 = 'z;
      end 
  end

  always @(posedge M_DUMP) begin
      $fdisplay(counter.log, "Mem DUMP, time = %0d", $time / 2); 
      for (i = 0; i < `MEM_SIZE; i++ ) begin
          $fdisplay(counter.mDump, "%d : %d", i, memLines[i]); 
      end       
  end

  always @(posedge RESET) begin   
     $fdisplay(counter.log, "Mem RESET, time = %0d", $time / 2); 
      SEED = _SEED;
       for (int i = 0; i < `MEM_SIZE; i += 1) begin
          memLines[i] = $random(SEED)>>16;
       end 
  end
endmodule

