#include "kiss_fftr.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

struct kiss_fftr_state {
  kiss_fft_cfg substate;
  kiss_fft_cpx *tmpbuf;
  kiss_fft_cpx *super_twiddles;
};

kiss_fftr_cfg kiss_fftr_alloc(int nfft, int inverse_fft, void *mem, size_t *lenmem) {
  int i;
  kiss_fftr_cfg st = NULL;
  size_t subsize = 0;
  size_t memneeded;

  if (nfft & 1) return NULL;

  kiss_fft_alloc(nfft / 2, inverse_fft, NULL, &subsize);
  memneeded = sizeof(struct kiss_fftr_state) + subsize + sizeof(kiss_fft_cpx) * (nfft / 2) +
              sizeof(kiss_fft_cpx) * (nfft / 2);

  if (lenmem == NULL) {
    st = (kiss_fftr_cfg)KISS_FFT_TMP_ALLOC(memneeded);
  } else if (mem != NULL && *lenmem >= memneeded) {
    st = (kiss_fftr_cfg)mem;
    *lenmem = memneeded;
  } else {
    *lenmem = memneeded;
    return NULL;
  }
  if (!st) return NULL;

  st->substate = (kiss_fft_cfg)(st + 1);
  st->tmpbuf = (kiss_fft_cpx *)(((char *)st->substate) + subsize);
  st->super_twiddles = st->tmpbuf + nfft / 2;

  kiss_fft_alloc(nfft / 2, inverse_fft, st->substate, &subsize);

  for (i = 0; i < nfft / 2; ++i) {
    double phase = (inverse_fft ? M_PI : -M_PI) * (i + 0.5) / (nfft / 2);
    st->super_twiddles[i].r = (kiss_fft_scalar)cos(phase);
    st->super_twiddles[i].i = (kiss_fft_scalar)sin(phase);
  }
  return st;
}

void kiss_fftr(kiss_fftr_cfg cfg, const kiss_fft_scalar *timedata, kiss_fft_cpx *freqdata) {
  int k, ncfft;
  kiss_fft_cpx fpnk, fpk, f1k, f2k, tw;
  ncfft = cfg->substate->nfft;

  kiss_fft(cfg->substate, (const kiss_fft_cpx *)timedata, cfg->tmpbuf);

  freqdata[0].r = cfg->tmpbuf[0].r + cfg->tmpbuf[0].i;
  freqdata[0].i = 0;
  freqdata[ncfft].r = cfg->tmpbuf[0].r - cfg->tmpbuf[0].i;
  freqdata[ncfft].i = 0;

  for (k = 1; k <= ncfft / 2; ++k) {
    fpk = cfg->tmpbuf[k];
    fpnk.r = cfg->tmpbuf[ncfft - k].r;
    fpnk.i = -cfg->tmpbuf[ncfft - k].i;

    f1k.r = fpk.r + fpnk.r;
    f1k.i = fpk.i + fpnk.i;
    f2k.r = fpk.r - fpnk.r;
    f2k.i = fpk.i - fpnk.i;

    tw = cfg->super_twiddles[k];
    freqdata[k].r = 0.5f * (f1k.r + (f2k.r * tw.r - f2k.i * tw.i));
    freqdata[k].i = 0.5f * (f1k.i + (f2k.i * tw.r + f2k.r * tw.i));

    freqdata[ncfft - k].r = 0.5f * (f1k.r - (f2k.r * tw.r - f2k.i * tw.i));
    freqdata[ncfft - k].i = -0.5f * (f1k.i - (f2k.i * tw.r + f2k.r * tw.i));
  }
}

void kiss_fftri(kiss_fftr_cfg cfg, const kiss_fft_cpx *freqdata, kiss_fft_scalar *timedata) {
  int k, ncfft;
  kiss_fft_cpx fk, fnkc, fek, fok, tmp;
  ncfft = cfg->substate->nfft;

  for (k = 1; k <= ncfft / 2; ++k) {
    fk = freqdata[k];
    fnkc.r = freqdata[ncfft - k].r;
    fnkc.i = -freqdata[ncfft - k].i;

    fek.r = fk.r + fnkc.r;
    fek.i = fk.i + fnkc.i;
    fok.r = fk.r - fnkc.r;
    fok.i = fk.i - fnkc.i;

    tmp = cfg->super_twiddles[k];
    tmp.r *= fok.r;
    tmp.i *= fok.i;

    cfg->tmpbuf[k].r = 0.5f * (fek.r + tmp.r);
    cfg->tmpbuf[k].i = 0.5f * (fek.i + tmp.i);
    cfg->tmpbuf[ncfft - k].r = 0.5f * (fek.r - tmp.r);
    cfg->tmpbuf[ncfft - k].i = -0.5f * (fek.i - tmp.i);
  }
  cfg->tmpbuf[0].r = freqdata[0].r + freqdata[ncfft].r;
  cfg->tmpbuf[0].i = freqdata[0].r - freqdata[ncfft].r;

  kiss_fft(cfg->substate, cfg->tmpbuf, (kiss_fft_cpx *)timedata);
}
