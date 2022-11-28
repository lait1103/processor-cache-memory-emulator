`include "constants.sv"
`include "mem.sv"
`include "cpu.sv"
`include "cache.sv"

module test;
   bit clk = 0;
   wire [`ADDR1_BUS_SIZE - 1 : 0] a1;
   wire [`DATA1_BUS_SIZE - 1 : 0] d1;
   wire [`CTR1_BUS_SIZE - 1 : 0] c1;
   wire [`DATA2_BUS_SIZE - 1 : 0] d2;
   wire [`CTR2_BUS_SIZE - 1 : 0] c2;
   wire [`ADDR2_BUS_SIZE - 1 : 0] a2;

   bit C_DUMP;
   bit M_DUMP;
   bit RESET;

   cache myChace(clk, C_DUMP, RESET, a1, d1, c1, d2, c2, a2);
   mem myMem(clk, M_DUMP, RESET, d2, c2, a2);
   cpu myCpu(clk, a1, d1, c1);

  initial begin
      for(int i = 0; i < 15000000; i++) begin
          #1;
          clk = 1 - clk;
      end
  end

endmodule

module counter;
  integer hits = 0;
  integer misses = 0;
  integer mDump = 0;
  integer cDump = 0;
  integer log = 0;
endmodule
