`include "constants.sv"

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
                $fdisplay(counter.log, "Cache hit in read, time = %0d", $time / 2); 
                lastUsed[readedSet] = i;
                counter.hits++;
                `delay(`CACHE_HIT_WAIT * 2 - 3 - 1, 1) // - 3 cause we have already wait 3 half ticks. - 1 cause we read info after 0.5 ticks
                target = i;
            end
            end
        end

        // miss
        if(target == -1) begin
            $fdisplay(counter.log, "Cache mis in read, time = %0d", $time / 2); 
            counter.misses++;
            target = 1 - lastUsed[readedSet];
            `delay(`CACHE_MIS_WAIT * 2 - 4, 1)

            // DIRTY
            if(lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] == 1 && lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] == 1) begin
                $fdisplay(counter.log, "Dirty line in read, time = %0d", $time / 2); 
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
                $fdisplay(counter.log, "Cache hit in write, time = %0d", $time / 2); 
                lastUsed[readedSet] = i;
                counter.hits++;
                `delay(`CACHE_HIT_WAIT * 2 - 3 - 1, 1) // - 3 cause we have already wait 3 half ticks. - 1 cause we read info after 0.5 ticks
                target = i;
            end
            end
        end

        // miss
        if(target == -1) begin
            $fdisplay(counter.log, "Cache mis in write, time = %0d", $time / 2); 
            counter.misses++;
            target = 1 - lastUsed[readedSet];
            `delay(`CACHE_MIS_WAIT * 2 - 4, 1)

            // DIRTY
            if(lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID - `DIRTY] == 1 && lines[readedSet][target][`CACHE_LINE_WHOLE_SIZE_BITS - `VALID] == 1) begin
                $fdisplay(counter.log, "Dirty line in write, time = %0d", $time / 2); 
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
        $fdisplay(counter.log, "Line invalidation, time = %0d", $time / 2); 
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
    $fdisplay(counter.log, "Сache DUMP, time = %0d", $time / 2); 
    for (i = 0; i < `CACHE_LINE_COUNT / `CACHE_WAY; i++ ) begin
        $fdisplay(counter.cDump, "%d: %d %d %d %d", 2 * i, lines[i][0][127 : 96], lines[i][0][95 : 64], lines[i][0][63 : 31], lines[i][0][31 : 0]); 
        $fdisplay(counter.cDump, "%d: %d %d %d %d", 2 * i + 1, lines[i][1][127 : 96], lines[i][1][95 : 64], lines[i][1][63 : 31], lines[i][1][31 : 0]); 
    end       
  end

  always @(posedge RESET) begin   
    $fdisplay(counter.log, "Cache RESET, time = %0d", $time / 2); 
    for(int i = 0; i < `CACHE_LINE_COUNT / `CACHE_WAY; i++) begin
        for(int j = 0; j < `CACHE_WAY; j++) begin
            lines[i][j] = 0;
        end
            lastUsed[i] = 0;
    end
  end
endmodule
