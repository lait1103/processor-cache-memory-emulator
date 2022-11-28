#pragma once

#include <vector>
#include <numeric>
#include <iostream>
#include "Counter.h"

using uint = unsigned int;
using ull = unsigned long long;
const uint bitsInByte = 8;

const uint CACHE_LINE_COUNT = 64;
const uint CACHE_WAY = 2;

/// time
const uint cacheHitWait = 6;
const uint cacheMisWait = 4;
const uint memCTRWait = 100;

/// in bytes
const uint CACHE_LINE_SIZE = 16;
const uint DATA_BUS_SIZE = 16 / bitsInByte;

/// in bits
const uint CACHE_OFFSET_SIZE = log2(CACHE_LINE_SIZE);
const uint CACHE_SET_SIZE = log2(CACHE_LINE_COUNT / CACHE_WAY);
const uint CACHE_TAG_SIZE = 10;
const uint ullSize = sizeof(ull) * bitsInByte;

class Cache {
public:
    Cache();

    template<uint bits>
    void read(ull uintAddress);

    template<uint bits>
    void write(ull uintAddress);

    inline void incr() { counter.increment(); }

    inline void incrExtra() { counter.incrementExtra(); }

    inline void mul() { counter.mul(); }

    inline void add() { counter.add(); }

    inline void printStats() {
        counter.printStats();
    }

private:
    struct Address {
        uint tag;
        uint set;
        uint offset;
    };

    struct Line {
        bool valid = false;
        bool dirty = false;
        bool lastUsed = false; /// we can use it because CACHE_WAY == 2
        uint tag = 0;
    };

    static Address uint2Address(ull address);

    inline static uint takeLastNBits(ull from, uint n) {
        return (from << (ullSize - n)) >> (ullSize - n);
    }

    template<uint bytes>
    void mis(const Address &address, bool haveToBecomeDirty = true);

    template<uint bytes>
    void hit(const Address &address, bool haveToSendBack = true);

    std::vector<Line> lines;
    Counter counter;
};

template<uint bits>
void Cache::read(ull uintAddress) {
    const uint bytes = bits / bitsInByte;
    counter.increment(2);  // to send address
    Address address = uint2Address(uintAddress);
    for (uint lineAddress = CACHE_WAY * address.set; lineAddress < CACHE_WAY * (1 + address.set); lineAddress++) {
        Line &line = lines[lineAddress];
        if (line.tag == address.tag) {
            if (line.valid) {
                line.lastUsed = true;
                lines[lineAddress ^ 1].lastUsed = false;
                hit<bytes>(address);
                return;
            }
        }
    }

    mis<bytes>(address, false);
}

template<uint bits>
void Cache::write(ull uintAddress) {
    const uint bytes = bits / bitsInByte;
    counter.increment(2); // to send address and data
    Address address = uint2Address(uintAddress);
    for (uint lineAddress = CACHE_WAY * address.set; lineAddress < CACHE_WAY * (1 + address.set); lineAddress++) {
        Line &line = lines[lineAddress];
        if (line.tag == address.tag) {
            if (line.valid) {
                hit<bytes>(address, false);
                line.lastUsed = true;
                line.dirty = true;
                lines[lineAddress ^ 1].lastUsed = false;
                return;
            }
        }
    }

    mis<bytes>(address, true);
}

template<uint bytes>
void Cache::mis(const Cache::Address &address, bool haveToBecameDirty) {
    counter.increment(cacheMisWait - 2); // because we have sent address
    counter.increment(memCTRWait);
    counter.increment(CACHE_LINE_SIZE / DATA_BUS_SIZE);
    counter.mis();
    counter.increment(2); //send data back to cpu
    for (uint lineAddress = CACHE_WAY * address.set; lineAddress < CACHE_WAY * (1 + address.set); lineAddress++) {
        Line &line = lines[lineAddress];
        if (not line.lastUsed) {
            line.valid = true;
            if (line.dirty) {
                // sending old cache line back;
                counter.increment(memCTRWait);
            }
            line.dirty = haveToBecameDirty;
            line.tag = address.tag;
            line.lastUsed = true;
            lines[lineAddress ^ 1].lastUsed = false;
            return;
        }
    }

    counter.increment((bytes - 1) / DATA_BUS_SIZE);
}

template<uint bytes>
void Cache::hit(const Cache::Address &address, bool haveToSandBack) {
    counter.increment(cacheHitWait - 2); // cause we have sent address
    counter.hit();
    if (haveToSandBack)
        counter.increment((bytes + 1) / 2); // to send data back
    else
        counter.increment(); // to get responce
}
