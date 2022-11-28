`include "constants.sv"

module cpu(input clk, output wire [`ADDR1_BUS_SIZE - 1 : 0] a1, inout wire [`DATA1_BUS_SIZE - 1 : 0] d1, inout wire [`CTR1_BUS_SIZE - 1 : 0] c1);
  reg [`DATA1_BUS_SIZE - 1 : 0] cpu_d1 = 'z;
  reg [`ADDR1_BUS_SIZE - 1 : 0] cpu_a1 = 'z;
  reg [`CTR1_BUS_SIZE - 1 : 0]  cpu_c1 = 'z;
  assign a1 = cpu_a1;
  assign d1 = cpu_d1;
  assign c1 = cpu_c1;

  reg [ 7 : 0] resultRead8   = 'z;
  reg [15 : 0] resultRead16  = 'z;
  reg [31 : 0] resultWrite32 = 'z;

  bit wantsToRead8 = 0;
  bit wantsToRead16 = 0;
  bit wantsToWrite32 = 0;

  integer M = 64;
  integer N = 60;
  integer K = 32;
  integer a = 0;
  integer b = M * K;
  integer c = b + K * N * 2;
  integer s = 0;

  integer extraTicks = 0;

  int pa = 0, pb = 0, pc = 0;

  initial begin
    counter.mDump = $fopen("mDump.txt", "w");
    counter.cDump = $fopen("cDump.txt", "w");
    counter.log = $fopen("log.txt", "w");
    mmul();

    $display("Total ticks: %0t + %0t = %0t", $time / 2, extraTicks, $time / 2 + extraTicks);
    $display("Total memory accesses: %0d", counter.hits + counter.misses);
    $display("Cache hits: %0d", counter.hits);
    $display("Part of hits: %0f", counter.hits * 1.0 / (counter.hits  + counter.misses));
    test.M_DUMP = 1;
    test.C_DUMP = 1;
    test.RESET = 1;
    wait(clk == 0);
    wait(clk == 1);
    $fclose(counter.log); 
    $fclose(counter.mDump); 
    $fclose(counter.cDump); 
  end

  task mmul;
      $fdisplay(counter.log, "Stardted working in mull(), time =  %0d", $time / 2); 
      pa = a;
      pc = c;
      extraTicks += 3; // pa, pc, y init
      for(int y = 0; y < M; y++) begin
          extraTicks += 1; // x init
          for(int x = 0; x < N; x++) begin
              pb = b;
              s = 0; 
              extraTicks += 3; // b, s, k init
              for(int k = 0; k < K; k++) begin
                  read8 (pa + k); // resultRead8
                  read16 (pb + x * 2); //resultRead16
                  s += resultRead8 * resultRead16;
                  pb += 2 * N;
                  extraTicks += 5 + 1 + 1; // mul, add, ad
                  extraTicks += 1; // loop
              end
              $fdisplay(counter.log, "Stardted writing 's', x = %0d, y = %0d, time = %0d", x, y, $time / 2); 
              write32 (pc + x * 4, s);
              $fdisplay(counter.log, "Finished writing 's', x = %0d, y = %0d, time = %0d", x, y, $time / 2); 
             extraTicks += 1; // loop
           end
           extraTicks += 1; // add
           extraTicks += 1; // add
           pa += K;
           pc += 4 * N;
           extraTicks += 1; // loop
        end
        extraTicks += 1; // func exit
        $fdisplay(counter.log, "Ended working in mull(), time =  %d", $time / 2); 
  endtask
  
  task read8 (reg [`ADDR1_BUS_SIZE + `CACHE_OFFSET_SIZE - 1 : 0] address);
    wait(clk == 1);
    cpu_c1 = `C1_READ8;
    cpu_a1 = address[`ADDR1_BUS_SIZE + `CACHE_OFFSET_SIZE - 1 : `CACHE_OFFSET_SIZE];
    `delay(2, 1)
    cpu_c1 = 'z;
    cpu_d1 = 'z;
    cpu_a1 = address[`CACHE_OFFSET_SIZE - 1 : 0];
    wantsToRead8 = 1;
    wait(wantsToRead8 == 0);
  endtask

  task read16 (reg [`ADDR1_BUS_SIZE + `CACHE_OFFSET_SIZE - 1 : 0] address);
    wait(clk == 1);
    cpu_c1 = `C1_READ16;
    cpu_a1 = address[`ADDR1_BUS_SIZE + `CACHE_OFFSET_SIZE - 1 : `CACHE_OFFSET_SIZE];
    `delay(2, 1)
    cpu_c1 = 'z;
    cpu_d1 = 'z;
    cpu_a1 = address[`CACHE_OFFSET_SIZE - 1 : 0];
    wantsToRead16 = 1;
    wait(wantsToRead16 == 0);
  endtask

  task write32 (reg [`ADDR1_BUS_SIZE + `CACHE_OFFSET_SIZE - 1 : 0] address, reg[31 : 0] data);
    wait(clk == 1);
    cpu_c1 = `C1_WRITE32;
    cpu_a1 = address[`ADDR1_BUS_SIZE + `CACHE_OFFSET_SIZE - 1 : `CACHE_OFFSET_SIZE];
    cpu_d1 = data[`DATA1_BUS_SIZE - 1 : 0];
    `delay(2, 1)
    cpu_c1 = 'z;
    cpu_a1 = address[`CACHE_OFFSET_SIZE - 1 : 0];
    cpu_d1 = data[`DATA1_BUS_SIZE * 2 - 1 : `DATA1_BUS_SIZE];
    wantsToWrite32 = 1;
    wait(wantsToWrite32 == 0);
  endtask

  always @(negedge clk) begin
      if(wantsToRead8 == 1 && c1 == `C1_RESPONSE) begin
         $fdisplay(counter.log, "Cpu got response in read8, time = %0d", $time / 2); 
         resultRead8 = d1[7 : 0];
         wantsToRead8 = 0;
      end else if (wantsToRead16 == 1 && c1 == `C1_RESPONSE) begin
         $fdisplay(counter.log, "Cpu got response in read16, time = %0d", $time / 2); 
         resultRead16 = d1[15 : 0];
         wantsToRead16 = 0;
      end else if (wantsToWrite32 == 1 && c1 == `C1_RESPONSE) begin
          $fdisplay(counter.log, "Cpu got response in write32, time = %0d", $time / 2); 
          cpu_d1 = 'z;
          wantsToWrite32 = 0;
      end  
  end
endmodule