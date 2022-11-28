// Created by my unimates
`define delay(TIME, CLOCK) \
    for (int i = 0; i < TIME; i++) begin \
        wait(clk == (i + !CLOCK) % 2); \
    end

`define BITS_IN_BYTE 8

`define CACHE_LINE_COUNT 64
`define CACHE_WAY 2
`define MEM_SIZE 524288 // 2 ^ 19

`define SEND_FROM_MEM (`CACHE_LINE_SIZE  / `DATA_BUS_SIZE)

// time
`define CACHE_HIT_WAIT 6
`define CACHE_MIS_WAIT 4
`define MEM_CTR_WAIT 100

// in bytes
`define CACHE_LINE_SIZE 16
`define DATA_BUS_SIZE (16 / `BITS_IN_BYTE)

// in bits
`define CACHE_OFFSET_SIZE 4 // log2(CACHE_LINE_SIZE);
`define CACHE_SET_SIZE 5  //  log2(CACHE_LINE_COUNT / CACHE_WAY);
`define CACHE_TAG_SIZE 10
`define CACHE_LINE_SIZE_BITS (`CACHE_LINE_SIZE * `BITS_IN_BYTE)
`define CACHE_LINE_WHOLE_SIZE_BITS (`VALID + `DIRTY + `CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BITS)
`define VALID 1
`define DIRTY 1
`define MAX_CPU_ASK 32 // read32 / write32

`define ADDR1_BUS_SIZE (`CACHE_SET_SIZE + `CACHE_TAG_SIZE)
`define ADDR2_BUS_SIZE (`CACHE_SET_SIZE + `CACHE_TAG_SIZE)

`define DATA1_BUS_SIZE 16
`define DATA2_BUS_SIZE 16

`define CTR1_BUS_SIZE 3
`define CTR2_BUS_SIZE 2

// comands
`define C1_NOP 3'b000
`define C1_READ8 3'b001
`define C1_READ16 3'b010
`define C1_READ32 3'b011
`define C1_INVALIDATE_LINE 3'b100
`define C1_WRITE8 3'b101
`define C1_WRITE16 3'b110
`define C1_WRITE32 3'b111
`define C1_RESPONSE 3'b111

`define C2_NOP 2'b00
`define C2_READ_LINE 2'b10
`define C2_WRITE_LINE 2'b11
`define C2_RESPONSE 2'b01



