#include "kiss_fft.h"

#include <assert.h>
#include <math.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846264338327
#endif

static kiss_fft_cpx *kiss_twiddles_create(int nfft, int inverse) {
  kiss_fft_cpx *tw = (kiss_fft_cpx *)KISS_FFT_TMP_ALLOC(sizeof(kiss_fft_cpx) * nfft);
  if (!tw) return NULL;
  const double phinc = (inverse ? 2 : -2) * M_PI / nfft;
  for (int i = 0; i < nfft; ++i) {
    const double phase = phinc * i;
    tw[i].r = (kiss_fft_scalar)cos(phase);
    tw[i].i = (kiss_fft_scalar)sin(phase);
  }
  return tw;
}

kiss_fft_cfg kiss_fft_alloc(int nfft, int inverse_fft, void *mem, size_t *lenmem) {
  kiss_fft_cfg st = NULL;
  size_t memneeded = sizeof(kiss_fft_state) + sizeof(kiss_fft_cpx) * nfft;
  if (lenmem == NULL) {
    st = (kiss_fft_cfg)KISS_FFT_TMP_ALLOC(memneeded);
  } else if (mem != NULL && *lenmem >= memneeded) {
    st = (kiss_fft_cfg)mem;
    *lenmem = memneeded;
  } else {
    *lenmem = memneeded;
    return NULL;
  }
  if (!st) return NULL;

  st->nfft = nfft;
  st->inverse = inverse_fft;
  st->twiddles = (kiss_fft_cpx *)(st + 1);
  kiss_fft_cpx *tmp = kiss_twiddles_create(nfft, inverse_fft);
  if (!tmp) return NULL;
  memcpy(st->twiddles, tmp, sizeof(kiss_fft_cpx) * nfft);
  KISS_FFT_TMP_FREE(tmp);
  return st;
}

static void kf_work(kiss_fft_cpx *Fout, const kiss_fft_cpx *f, int fstride, int in_stride,
                    int *factors, const kiss_fft_cfg st) {
  kiss_fft_cpx *Fout_beg = Fout;
  if (factors[1] == 1) {
    int k = factors[0];
    for (int i = 0; i < k; ++i) {
      Fout[i] = f[i * fstride * in_stride];
    }
  } else {
    int p = factors[0];
    int m = factors[1];
    factors += 2;
    for (int i = 0; i < p; ++i) {
      kf_work(Fout, f, fstride * p, in_stride, factors, st);
      Fout += m;
      f += fstride * in_stride;
    }
    Fout = Fout_beg;
    for (int k = 0; k < m; ++k) {
      kiss_fft_cpx t;
      kiss_fft_cpx *F = Fout + k;
      for (int i = 1; i < p; ++i) {
        const kiss_fft_cpx *tw = st->twiddles + (i * k * fstride) % st->nfft;
        t.r = F[i * m].r * tw->r - F[i * m].i * tw->i;
        t.i = F[i * m].r * tw->i + F[i * m].i * tw->r;
        F->r += t.r;
        F->i += t.i;
      }
    }
  }
}

static void kf_factor(int n, int *facbuf) {
  int p = 4;
  const int maxfac = 32;
  int *F = facbuf;
  do {
    while (n % p) {
      switch (p) {
        case 4:
          p = 2;
          break;
        case 2:
          p = 3;
          break;
        default:
          p += 2;
          break;
      }
      if (p > maxfac) p = n;
    }
    n /= p;
    *F++ = p;
    *F++ = n;
  } while (n > 1);
  *F = 0;
}

void kiss_fft_stride(kiss_fft_cfg cfg, const kiss_fft_cpx *fin, kiss_fft_cpx *fout, int ostride) {
  int factors[64];
  kf_factor(cfg->nfft, factors);
  kf_work(fout, fin, 1, ostride, factors, cfg);
  if (cfg->inverse) {
    for (int i = 0; i < cfg->nfft; ++i) {
      fout[i].r /= cfg->nfft;
      fout[i].i /= cfg->nfft;
    }
  }
}

void kiss_fft(kiss_fft_cfg cfg, const kiss_fft_cpx *fin, kiss_fft_cpx *fout) {
  kiss_fft_stride(cfg, fin, fout, 1);
}

void kiss_fft_cleanup(void) {
  /* nothing to do in this simple implementation */
}

int kiss_fft_next_fast_size(int n) {
  while (1) {
    int m = n;
    while ((m % 2) == 0) m /= 2;
    while ((m % 3) == 0) m /= 3;
    while ((m % 5) == 0) m /= 5;
    if (m == 1) break;
    n++;
  }
  return n;
}
