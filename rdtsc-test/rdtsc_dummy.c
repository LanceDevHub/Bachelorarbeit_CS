#include <stdint.h>
#include <stdio.h>

static inline uint64_t rdtsc(void) {
    unsigned int lo, hi;
    __asm__ volatile ("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

// Request-Struktur
typedef struct {
    volatile int buf;
    volatile int count;
    volatile int datatype;
    volatile int ep;    
    volatile int ucx_tag;
    volatile int comm;
} simple_request_t;

// ISEND-like: alle Parameter + Setup -> neuer Request
__attribute__((noinline))
void f_isend_like(int buf, int count, int datatype, int dest, int tag, int comm, simple_request_t *request)
{
    int ep;
    
    ep = comm + dest;               // mca_pml_ucx_get_ep() like
    int ucx_tag = tag + comm;      // PML_UCX_MAKE_SEND_TAG() like
    
    // mca_pml_ucx_common_send() like
    int req_update = ep + buf + count + datatype + ucx_tag + comm;
    request->buf = req_update;
}

// ISEND_INIT-like: Setup + SPEICHERN
__attribute__((noinline))
void f_isend_init_like(int buf, int count, int datatype, int dest, int tag, int comm, simple_request_t *request)
{
    int ep;
    
    // mca_pml_ucx_get_ep() like
    ep = comm + dest;
    
    request->buf      = buf;
    request->count    = count;
    request->datatype = datatype;
    request->ep       = ep;
    // PML_UCX_MAKE_SEND_TAG() like
    request->ucx_tag  = tag + comm;
    request->comm     = comm;
}

// START-like: gespeicherte Parameter nutzen
__attribute__((noinline))
void f_start_like(simple_request_t *request)
{
    // mca_pml_ucx_common_send() like
    int req_update = request->ep + request->buf + request->count + 
                     request->datatype + request->ucx_tag + request->comm;
                     
    request->buf = req_update;
}

static const int N = 1000;

uint64_t bench_start() {
    simple_request_t r;
    
    uint64_t start = rdtsc();
    f_isend_init_like(1, 2, 3, 4, 5, 6, &r);
    for (int i = 0; i < N; ++i) {
        f_start_like(&r);
    }
    uint64_t end = rdtsc();
    return (end - start) / N;
}

uint64_t bench_isend() {
    simple_request_t req = {1, 2, 3, 4, 5, 6};
    
    uint64_t start = rdtsc();
    for (int i = 0; i < N; ++i) {
        f_isend_like(1, 2, 3, 4, 5, 6, &req);
    }
    uint64_t end = rdtsc();
    return (end - start) / N;
}

int main() {
    bench_start();
    bench_isend();

    uint64_t c_start = bench_start();
    uint64_t c_isend = bench_isend();

    printf("f_start_like cycles/call : %llu\n", (unsigned long long)c_start);
    printf("f_isend_like cycles/call : %llu\n", (unsigned long long)c_isend);
    printf("ratio (isend/start)      : %.2f\n", (double)c_isend / c_start);

    return 0;
}
