#include "Cache.h"

using namespace std;
using uint = unsigned int;

const uint M = 64;
const uint N = 60;
const uint K = 32;

int8_t a[M][K];
int16_t b[K][N];
int32_t c[M][N];


void mmul(Cache &cache) {
    int s;
    cache.incrExtra(); // pa init
    int8_t *pa = a[0];
    cache.incrExtra(); // pc init
    int32_t *pc = c[0];
    cache.incrExtra(); // y init
    for (int y = 0; y < M; y++) {
        cache.incrExtra(); // x init
        for (int x = 0; x < N; x++) {
            cache.incrExtra(); // pb init
            int16_t *pb = &b[0][0];
            cache.incrExtra(); // s init
            s = 0;
            cache.incrExtra(); // k init
            for (int k = 0; k < K; k++) {
                cache.read<8>(reinterpret_cast<unsigned long long int>(pa + k));
                cache.read<16>(reinterpret_cast<unsigned long long int>(pb + x));
                cache.mul();
                cache.add();
                cache.add();
                pb += N;
                cache.incrExtra(); // loop
                cache.incrExtra(); // loop
            }
            cache.write<32>(reinterpret_cast<unsigned long long int>(pc + x));
            cache.incrExtra(); // loop
            cache.incrExtra(); // loop
        }
        cache.add();
        cache.add();
        pa += K;
        pc += N;
        cache.incrExtra(); // loop
        cache.incrExtra(); // loop
    }
    cache.incrExtra(); // function exit
}

int main() {
    Cache cache = Cache();
    mmul(cache);
    cache.printStats();

    return 0;
}
