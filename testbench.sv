`include "constants.sv"
// Created by my unimate
`define delay(TIME, CLOCK) \
    for (int i = 0; i < TIME; i++) begin \
        wait(clk == (i + !CLOCK) % 2); \
    end

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
endmodule

// clk == 0 -> reads; clk == 1 -> writes;
module cache(input clk, input C_DUMP, input RESET, input wire [`ADDR1_BUS_SIZE - 1 : 0] a1, inout wire [`DATA1_BUS_SIZE - 1 : 0] d1, inout wire [`CTR1_BUS_SIZE - 1 : 0] c1, inout wire [`DATA2_BUS_SIZE - 1 : 0] d2, inout wire [`CTR2_BUS_SIZE - 1 : 0] c2, output wire [`ADDR2_BUS_SIZE - 1 : 0] a2);
  reg [`CACHE_LINE_WHOLE_SIZE_BITS - 1 : 0] lines[`CACHE_LINE_COUNT / `CACHE_WAY - 1 : 0][`CACHE_WAY - 1 : 0];
  bit lastUsed [`CACHE_LINE_COUNT / `CACHE_WAY - 1 : 0];

  reg [`DATA1_BUS_SIZE - 1 : 0] cache_d1 = 'z;
  reg [`CTR1_BUS_SIZE - 1 : 0] cache_c1 = 'z;
  reg [`DATA2_BUS_SIZE - 1 : 0] cache_d2 = 'z;
  reg [`CTR2_BUS_SIZE - 1 : 0] cache_c2 = 'z;
  reg [`ADDR2_BUS_SIZE - 1 : 0] cache_a2 = 'z;
  assign d1 = cache_d1;
  assign c1 = cache_c1;
  assign d2 = cache_d2;
  assign c2 = cache_c2;
  assign a2 = cache_a2;

  initial begin
      for(int i = 0; i < `CACHE_LINE_COUNT / `CACHE_WAY; i++) begin
          for(int j = 0; j < `CACHE_WAY; j++) begin
            lines[i][j] = 0;
          end
          lastUsed[i] = 0;
      end
  end

  bit [`CACHE_TAG_SIZE - 1 : 0] readedTag;
  bit [`CACHE_SET_SIZE - 1 : 0] readedSet;
  bit [`CACHE_OFFSET_SIZE - 1 : 0] readedOffset;

  bit [`MAX_CPU_ASK - 1 : 0] tmpBuffer;

  integer target = -1; // it helps to write back to cpu only once
  integer whatToDoWithCpu = 0; // just last command
  integer i = 0;

  integer wantsToWriteToMemory = 0;
  integer wantsToReadFromMemory = 0;

  always @(negedge clk) begin
    // READ
    if (c1 == `C1_READ8 || c1 == `C1_READ16 ||c1 == `C1_READ32) begin
        whatToDoWithCpu = c1;
        readedTag[`CACHE_TAG_SIZE - 1 : 0] = a1[`ADDR1_BUS_SIZE - 1 : `CACHE_SET_SIZE];
        readedSet[`CACHE_SET_SIZE - 1 : 0] = a1[`CACHE_SET_SIZE - 1 : 0];
        `delay(2, 0)
        readedOffset[`CACHE_OFFSET_SIZE - 1 : 0] = a1[`CACHE_OFFSET_SIZE - 1 : 0];
        `delay(1, 0)
        target = -1;
        cache_c1 = `C1_NOP;
        for(i = 0; i < `CACHE_WAY && (target == -1); i++) begin
            if(lines[readedSet][i][`CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BITS - 1 : `CACHE_LINE_SIZE_BITS] == readedTag) begin
            // hit
            if(lines[readedSet][i][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] == 1) begin
                lastUsed[readedSet] = i;
                counter.hits++;
                `delay(`CACHE_HIT_WAIT * 2 - 3 - 1, 1) // - 3 cause we have already wait 3 half ticks. - 1 cause we read info after 0.5 ticks
                target = i;
            end
            end
        end

        // miss
        if(target == -1) begin
            counter.misses++;
            target = 1 - lastUsed[readedSet];
            `delay(`CACHE_MIS_WAIT * 2 - 4, 1)

            // DIRTY
            if(lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] == 1 && lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] == 1) begin
                cache_c2 = `C2_WRITE_LINE;
                cache_a2[`CACHE_SET_SIZE - 1 : 0] = readedSet;
                cache_a2[`ADDR2_BUS_SIZE - 1 : `CACHE_SET_SIZE] = lines[readedSet][target][`CACHE_LINE_SIZE_BITS + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BITS];
                wantsToWriteToMemory = 1;
                wait(wantsToWriteToMemory == 0);
                `delay(1, 0)
            end
            cache_c2[`CTR2_BUS_SIZE - 1 : 0] = `C2_READ_LINE;
            cache_a2[`CACHE_SET_SIZE - 1 : 0] = readedSet;
            cache_a2[`ADDR2_BUS_SIZE - 1 : `CACHE_SET_SIZE] = readedTag;
            `delay(2, 1)
            cache_c2[`CTR2_BUS_SIZE - 1 : 0] = 'z;
            cache_a2[`ADDR2_BUS_SIZE - 1 : 0] = 'z;
            cache_d2[`DATA2_BUS_SIZE - 1 : 0] = 'z;
            wantsToReadFromMemory = 1;
            wait(wantsToReadFromMemory == 0);

            lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] = 0;
            lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] = 1;
            lines[readedSet][target][`CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BITS - 1 : `CACHE_LINE_SIZE_BITS] = readedTag;
            lastUsed[readedSet] = target;
            `delay(1, 0)
        end
        
        cache_c1 = `C1_RESPONSE;
        case (whatToDoWithCpu)
        `C1_READ8 : begin
        cache_d1[7 : 0] =  lines[readedSet][target][readedOffset * 8 +: 8];
        end
        `C1_READ16 : begin
        cache_d1[15 : 0] =  lines[readedSet][target][readedOffset * 8 +: 16];
        end 
        `C1_READ32 : begin
            cache_d1[15 : 0] =  lines[readedSet][target][readedOffset * 8 +: 16];
            `delay(2, 1)
            cache_d1[15 : 0] =  lines[readedSet][target][16 + readedOffset +: 16];
        end
        endcase

        `delay(2, 1)
        cache_c1 = 'z;
        cache_d1 = 'z;
    end 
    // WRITE 
    else if (c1 == `C1_WRITE8 || c1 == `C1_WRITE16 || c1 == `C1_WRITE32) begin
        whatToDoWithCpu = c1;
        readedTag[`CACHE_TAG_SIZE - 1 : 0] = a1[`ADDR1_BUS_SIZE - 1 : `CACHE_SET_SIZE];
        readedSet[`CACHE_SET_SIZE - 1 : 0] = a1[`CACHE_SET_SIZE - 1 : 0];
        tmpBuffer[15 : 0] = d1;
        `delay(2, 0)
        readedOffset[`CACHE_OFFSET_SIZE - 1 : 0] = a1[`CACHE_OFFSET_SIZE - 1 : 0];
        tmpBuffer[31 : 16] = d1; // better not to do like that when command != write32;
        `delay(1, 0)
        target = -1;
        cache_c1 = `C1_NOP;
        for(i = 0; i < `CACHE_WAY && (target == -1); i++) begin
            if(lines[readedSet][i][`CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BITS - 1 : `CACHE_LINE_SIZE_BITS] == readedTag) begin
            // hit
            if(lines[readedSet][i][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID]) begin
                lastUsed[readedSet] = i;
                counter.hits++;
                `delay(`CACHE_HIT_WAIT * 2 - 3 - 1, 1) // - 3 cause we have already wait 3 half ticks. - 1 cause we read info after 0.5 ticks
                target = i;
            end
            end
        end

        // miss
        if(target == -1) begin
            counter.misses++;
            target = 1 - lastUsed[readedSet];
            `delay(`CACHE_MIS_WAIT * 2 - 4, 1)

            // DIRTY
            if(lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] == 1 && lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] == 1) begin
                cache_c2 = `C2_WRITE_LINE;
                cache_a2[`CACHE_SET_SIZE - 1 : 0] = readedSet;
                cache_a2[`ADDR2_BUS_SIZE - 1 : `CACHE_SET_SIZE] = lines[readedSet][target][`CACHE_LINE_SIZE_BITS + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BITS];
                wantsToWriteToMemory = 1;
                wait(wantsToWriteToMemory == 0);
                `delay(1, 0)
            end

            cache_c2[`CTR2_BUS_SIZE - 1 : 0] = `C2_READ_LINE;
            cache_a2[`CACHE_SET_SIZE - 1 : 0] = readedSet;
            cache_a2[`ADDR2_BUS_SIZE - 1 : `CACHE_SET_SIZE] = readedTag;
            `delay(2, 1)

            cache_c2[`CTR2_BUS_SIZE - 1 : 0] = 'z;
            cache_a2[`ADDR2_BUS_SIZE - 1 : 0] = 'z;
            cache_d2[`DATA2_BUS_SIZE - 1 : 0] = 'z;
            wantsToReadFromMemory = 1;
            wait(wantsToReadFromMemory == 0);

            lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] = 1;
            lines[readedSet][target][`CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BITS - 1 : `CACHE_LINE_SIZE_BITS] = readedTag;
            lastUsed[readedSet] = target;
            `delay(1, 0)
        end

        // save data:
        lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] = 1;

        case (whatToDoWithCpu)
        `C1_WRITE8 : begin
            lines[readedSet][target][readedOffset * 8 +: 8] = tmpBuffer[7 : 0];
        end
        `C1_WRITE16 : begin
            lines[readedSet][target][readedOffset * 8 +: 16] = tmpBuffer[15 : 0];
        end 
        `C1_WRITE32 : begin
            lines[readedSet][target][readedOffset * 8 +: 32] = tmpBuffer[31 : 0];
        end
        endcase


        cache_c1 = `C1_RESPONSE;
        `delay(2, 1)
        cache_c1 = 'z;
        cache_d1 = 'z;
    end 
    // INVALIDATE
    else if (c1 == `C1_INVALIDATE_LINE) begin
        whatToDoWithCpu = cache_c1;
        readedTag[`CACHE_TAG_SIZE - 1 : 0] = a1[`ADDR1_BUS_SIZE - 1 : `CACHE_SET_SIZE];
        readedSet[`CACHE_SET_SIZE - 1 : 0] = a1[`CACHE_SET_SIZE - 1 : 0];
        `delay(2, 0)
        readedOffset[`CACHE_OFFSET_SIZE - 1 : 0] = a1[`CACHE_OFFSET_SIZE - 1 : 0];
        `delay(1, 0)
        target = -1;
        cache_c1 = `C1_NOP;
        for(i = 0; i < `CACHE_WAY && (target == -1); i++) begin
            if(lines[readedSet][i][`CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BITS - 1 : `CACHE_LINE_SIZE_BITS] == readedTag) begin
            // hit
            if(lines[readedSet][i][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID]) begin
                lastUsed[readedSet] = i;
                counter.hits++; // ?
                `delay(`CACHE_HIT_WAIT * 2 - 3 - 1, 1) // - 3 cause we have already wait 3 half ticks. - 1 cause we read info after 0.5 ticks
                target = i;
                
                //  invalidation
                if(lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] == 1) begin
                    cache_c2 = `C2_WRITE_LINE;
                    cache_a2[`CACHE_SET_SIZE - 1 : 0] = readedSet;
                    cache_a2[`ADDR2_BUS_SIZE - 1 : `CACHE_SET_SIZE] = readedTag;
                    wantsToWriteToMemory = 1;
                    wait(wantsToWriteToMemory == 0);
                    `delay(1, 0)
                    end
                    lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] = 0;
                    lines[readedSet][i][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] = 0;
                end
            end
        end
    end
  end

  always @(clk) begin
      if(wantsToWriteToMemory == 1 && clk == 1) begin
          for(i = 0; i < `SEND_FROM_MEM; i++) begin
             cache_d2 = lines[readedSet][target][`DATA2_BUS_SIZE * i +: `DATA2_BUS_SIZE];
             `delay(2, 1)
              cache_c2[`CTR2_BUS_SIZE - 1 : 0] = 'z;
              cache_a2[`ADDR2_BUS_SIZE - 1 : 0] = 'z;
          end
          wantsToWriteToMemory = 2;
      end else if (clk == 0 && wantsToReadFromMemory == 1 && c2 == `C2_RESPONSE) begin
            for(i = 0; i < `SEND_FROM_MEM; i++) begin
                lines[readedSet][target][`DATA2_BUS_SIZE * i +: `DATA2_BUS_SIZE] = d2;
                `delay(2, 0)
            end
            wantsToReadFromMemory = 0;
      end 
  end

  always @(negedge clk) begin
      if (wantsToWriteToMemory == 2 && c2 == `C2_RESPONSE) wantsToWriteToMemory = 0;
  end

  always @(posedge C_DUMP) begin
    for (i = 0; i < `CACHE_LINE_COUNT / `CACHE_WAY; i++ ) begin
        $fdisplay(counter.cDump, "%d: %d %d %d %d", 2 * i, lines[i][0][127 : 96], lines[i][0][95 : 64], lines[i][0][63 : 31], lines[i][0][31 : 0]); 
        $fdisplay(counter.cDump, "%d: %d %d %d %d", 2 * i + 1, lines[i][1][127 : 96], lines[i][1][95 : 64], lines[i][1][63 : 31], lines[i][1][31 : 0]); 
    end       
  end

  always @(posedge RESET) begin   
    for(int i = 0; i < `CACHE_LINE_COUNT / `CACHE_WAY; i++) begin
        for(int j = 0; j < `CACHE_WAY; j++) begin
            lines[i][j] = 0;
        end
            lastUsed[i] = 0;
    end
  end
endmodule

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
        readedSetTag = a2;
        for(i = 0; i < `SEND_FROM_MEM; i++) begin
            memLines[readedSetTag * (1 << `CACHE_OFFSET_SIZE) + 2 * i] = d2[`BITS_IN_BYTE - 1 : 0];
            memLines[readedSetTag * (1 << `CACHE_OFFSET_SIZE) + 2 * i + 1] = d2[`DATA2_BUS_SIZE - 1 : `BITS_IN_BYTE];
            `delay(2, 0)
        end
       `delay(`MEM_CTR_WAIT * 2 - `SEND_FROM_MEM * 2 - 3, 0)
        mem_c2 = `C2_RESPONSE;
        `delay(2, 1)
        mem_c2 = 'z;
      end 
  end

  always @(posedge M_DUMP) begin
      for (i = 0; i < `MEM_SIZE; i++ ) begin
          $fdisplay(counter.mDump, "%d : %d", i, memLines[i]); 
      end       
  end

  always @(posedge RESET) begin   
      SEED = _SEED;
       for (int i = 0; i < `MEM_SIZE; i += 1) begin
          memLines[i] = $random(SEED)>>16;
       end 
  end
endmodule

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
    mmul();


    $display("Total ticks: %0t, %0t", $time / 2, extraTicks);
    $display("Total accesses: %0d", counter.hits + counter.misses);
    $display("Cache hits: %0d", counter.hits);
    $display("Part of hits: %0f", counter.hits * 1.0 / (counter.hits  + counter.misses));
    test.M_DUMP = 1;
    test.C_DUMP = 1;
    test.RESET = 1;
    wait(clk == 0);
    wait(clk == 1);
    $fclose(counter.mDump); 
    $fclose(counter.cDump); 
  end

  task mmul;
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
              write32 (pc + x * 4, s);
             extraTicks += 1; // loop
           end
           extraTicks += 1; // add
           extraTicks += 1; // add
           pa += K;
           pc += 4 * N;
           extraTicks += 1; // loop
        end
        extraTicks += 1; // func exit
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
         resultRead8 = d1[7 : 0];
         wantsToRead8 = 0;
      end else if (wantsToRead16 == 1 && c1 == `C1_RESPONSE) begin
         resultRead16 = d1[15 : 0];
         wantsToRead16 = 0;
      end else if (wantsToWrite32 == 1 && c1 == `C1_RESPONSE) begin
          cpu_d1 = 'z;
          wantsToWrite32 = 0;
      end  
  end
endmodule