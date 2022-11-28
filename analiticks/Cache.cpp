#include "Cache.h"

Cache::Address Cache::uint2Address(ull address) {
    uint offset = takeLastNBits(address, CACHE_OFFSET_SIZE);
    uint set = takeLastNBits(address >> CACHE_OFFSET_SIZE, CACHE_SET_SIZE);
    uint tag = takeLastNBits(address >> (CACHE_OFFSET_SIZE + CACHE_SET_SIZE), CACHE_TAG_SIZE);
    return Address{tag, set, offset};
}

Cache::Cache() {
    lines.resize(CACHE_LINE_COUNT);
}

