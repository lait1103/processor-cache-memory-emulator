#pragma once
using uint = unsigned int;

class Counter {
public:
    inline void add() { extraTicks++; }

    inline void mul() { extraTicks += 5; }

    inline void increment(uint times = 1) { clock += times; }

    inline void incrementExtra(uint times = 1) { extraTicks += times; }

    inline void hit() { hits++; }

    inline void mis() { mises++; }

    inline void printStats() {
        std::cout << "Total ticks: " << clock << " + " << extraTicks << " = " << extraTicks + clock  << "\nTotal memory accesses: " << mises + hits << '\n' <<  "Cache hits: " << hits << '\n'
                  << "Part of hits: " << hits * 1.0 / (hits + mises);
    }

private:
    uint clock = 0;
    uint mises = 0;
    uint hits = 0;
    uint extraTicks = 0;
};


