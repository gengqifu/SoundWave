/* kiss_fft.h
   originally by Mark Borgerding, placed in public domain, with BSD-like license retained in COPYING
*/

#ifndef KISS_FFT_H
#define KISS_FFT_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef KISS_FFT_USE_ALLOCA
#include <alloca.h>
#define KISS_FFT_TMP_ALLOC(nbytes) alloca(nbytes)
#define KISS_FFT_TMP_FREE(x)
#else
#include <stdlib.h>
#define KISS_FFT_TMP_ALLOC(nbytes) malloc(nbytes)
#define KISS_FFT_TMP_FREE(x) free(x)
#endif

#ifndef kiss_fft_scalar
#include <math.h>
typedef float kiss_fft_scalar;
#endif

typedef struct {
  kiss_fft_scalar r;
  kiss_fft_scalar i;
} kiss_fft_cpx;

typedef struct kiss_fft_state {
  int nfft;
  int inverse;
  kiss_fft_cpx *twiddles;
} kiss_fft_state;

typedef struct kiss_fft_state *kiss_fft_cfg;

kiss_fft_cfg kiss_fft_alloc(int nfft, int inverse_fft, void *mem, size_t *lenmem);

void kiss_fft_stride(kiss_fft_cfg cfg, const kiss_fft_cpx *fin, kiss_fft_cpx *fout, int ostride);

void kiss_fft(kiss_fft_cfg cfg, const kiss_fft_cpx *fin, kiss_fft_cpx *fout);

void kiss_fft_cleanup(void);

int kiss_fft_next_fast_size(int n);

#ifdef __cplusplus
}
#endif

#endif
