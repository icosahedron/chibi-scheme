
#include <chibi/eval.h>
#include <limits.h>

#if USE_BIGNUMS
#include <chibi/bignum.h>
#endif

static sexp sexp_bit_and (sexp ctx, sexp x, sexp y) {
  sexp res;
  sexp_sint_t len, i;
  if (sexp_fixnump(x)) {
    if (sexp_fixnump(y))
      res = (sexp) ((sexp_uint_t)x & (sexp_uint_t)y);
#if USE_BIGNUMS
    else if (sexp_bignump(y))
      res = sexp_bit_and(ctx, y, x);
#endif
    else
      res = sexp_type_exception(ctx, "bitwise-and: not an integer", y);
#if USE_BIGNUMS
  } else if (sexp_bignump(x)) {
    if (sexp_fixnump(y)) {
      res = sexp_make_fixnum(sexp_unbox_fixnum(y) & sexp_bignum_data(x)[0]);
    } else if (sexp_bignump(y)) {
      if (sexp_bignum_length(x) < sexp_bignum_length(y))
        res = sexp_copy_bignum(ctx, NULL, x, 0);
      else
        res = sexp_copy_bignum(ctx, NULL, y, 0);
      for (i=0, len=sexp_bignum_length(res); i<len; i++)
        sexp_bignum_data(res)[i]
          = sexp_bignum_data(x)[i] & sexp_bignum_data(y)[i];
    } else {
      res = sexp_type_exception(ctx, "bitwise-and: not an integer", y);
    }
#endif
  } else {
      res = sexp_type_exception(ctx, "bitwise-and: not an integer", x);
  }
  return sexp_bignum_normalize(res);
}

static sexp sexp_bit_ior (sexp ctx, sexp x, sexp y) {
  sexp res;
  sexp_sint_t len, i;
  if (sexp_fixnump(x)) {
    if (sexp_fixnump(y))
      res = (sexp) ((sexp_uint_t)x | (sexp_uint_t)y);
#if USE_BIGNUMS
    else if (sexp_bignump(y))
      res = sexp_bit_ior(ctx, y, x);
#endif
    else
      res = sexp_type_exception(ctx, "bitwise-ior: not an integer", y);
#if USE_BIGNUMS
  } else if (sexp_bignump(x)) {
    if (sexp_fixnump(y)) {
      res = sexp_copy_bignum(ctx, NULL, x, 0);
      sexp_bignum_data(x)[0] |= sexp_unbox_fixnum(y);
    } else if (sexp_bignump(y)) {
      if (sexp_bignum_length(x) >= sexp_bignum_length(y)) {
        res = sexp_copy_bignum(ctx, NULL, x, 0);
        len = sexp_bignum_length(y);
      } else {
        res = sexp_copy_bignum(ctx, NULL, y, 0);
        len = sexp_bignum_length(x);
      }
      for (i=0; i<len; i++)
        sexp_bignum_data(res)[i]
          = sexp_bignum_data(x)[i] | sexp_bignum_data(y)[i];
    } else {
      res = sexp_type_exception(ctx, "bitwise-ior: not an integer", y);
    }
#endif
  } else {
      res = sexp_type_exception(ctx, "bitwise-ior: not an integer", x);
  }
  return sexp_bignum_normalize(res);
}

static sexp sexp_bit_xor (sexp ctx, sexp x, sexp y) {
  sexp res;
  sexp_sint_t len, i;
  if (sexp_fixnump(x)) {
    if (sexp_fixnump(y))
      res = sexp_make_fixnum(sexp_unbox_fixnum(x) ^ sexp_unbox_fixnum(y));
#if USE_BIGNUMS
    else if (sexp_bignump(y))
      res = sexp_bit_xor(ctx, y, x);
#endif
    else
      res = sexp_type_exception(ctx, "bitwise-xor: not an integer", y);
#if USE_BIGNUMS
  } else if (sexp_bignump(x)) {
    if (sexp_fixnump(y)) {
      res = sexp_copy_bignum(ctx, NULL, x, 0);
      sexp_bignum_data(x)[0] ^= sexp_unbox_fixnum(y);
    } else if (sexp_bignump(y)) {
      if (sexp_bignum_length(x) >= sexp_bignum_length(y)) {
        res = sexp_copy_bignum(ctx, NULL, x, 0);
        len = sexp_bignum_length(y);
      } else {
        res = sexp_copy_bignum(ctx, NULL, y, 0);
        len = sexp_bignum_length(x);
      }
      for (i=0; i<len; i++)
        sexp_bignum_data(res)[i]
          = sexp_bignum_data(x)[i] ^ sexp_bignum_data(y)[i];
    } else {
      res = sexp_type_exception(ctx, "bitwise-xor: not an integer", y);
    }
#endif
  } else {
      res = sexp_type_exception(ctx, "bitwise-xor: not an integer", x);
  }
  return sexp_bignum_normalize(res);
}

/* should probably split into left and right shifts, that's a better */
/* interface anyway */
static sexp sexp_arithmetic_shift (sexp ctx, sexp i, sexp count) {
  sexp_gc_var1(res);
  sexp_sint_t c, len, offset, bit_shift, j;
  sexp_uint_t tmp;
  if (! sexp_fixnump(count))
    return sexp_type_exception(ctx, "arithmetic-shift: not an integer", count);
  c = sexp_unbox_fixnum(count);
  if (c == 0) return i;
  if (sexp_fixnump(i)) {
    if (c < 0) {
      res = sexp_make_fixnum(sexp_unbox_fixnum(i) >> -c);
    } else {
      tmp = (sexp_uint_t)sexp_unbox_fixnum(i) << c;
#if USE_BIGNUMS
      if (((tmp >> c) == sexp_unbox_fixnum(i))
          && (tmp < SEXP_MAX_FIXNUM) && (tmp > SEXP_MIN_FIXNUM)) {
#endif
        res = sexp_make_fixnum(tmp);
#if USE_BIGNUMS
      } else {
        sexp_gc_preserve1(ctx, res);
        res = sexp_fixnum_to_bignum(ctx, i);
        res = sexp_arithmetic_shift(ctx, res, count);
        sexp_gc_release1(ctx);
      }
#endif
    }
#if USE_BIGNUMS
  } else if (sexp_bignump(i)) {
    len = sexp_bignum_hi(i);
    if (c < 0) {
      c = -c;
      offset = c / (sizeof(sexp_uint_t)*CHAR_BIT);
      bit_shift = c - offset*(sizeof(sexp_uint_t)*CHAR_BIT);
      if (len < offset) {
        res = sexp_make_fixnum(sexp_bignum_sign(i) > 0 ? 0 : -1);
      } else {
        res = sexp_make_bignum(ctx, len - offset + 1);
        for (j=len-offset, tmp=0; j>=0; j--) {
          sexp_bignum_data(res)[j]
            = (sexp_bignum_data(i)[j+offset] >> bit_shift)+ tmp;
          tmp = sexp_bignum_data(i)[j+offset]
            << (sizeof(sexp_uint_t)*CHAR_BIT-bit_shift);
        }
      }
    } else {
      offset = c / (sizeof(sexp_uint_t)*CHAR_BIT);
      bit_shift = c - offset*(sizeof(sexp_uint_t)*CHAR_BIT);
      res = sexp_make_bignum(ctx, len + offset + 1);
      for (j=tmp=0; j<len; j++) {
        sexp_bignum_data(res)[j+offset]
          = (sexp_bignum_data(i)[j] << bit_shift) + tmp;
        tmp = sexp_bignum_data(i)[j] >> (sizeof(sexp_uint_t)*CHAR_BIT-bit_shift);
      }
      sexp_bignum_data(res)[len+offset] = tmp;
    }
#endif
  } else {
    res = sexp_type_exception(ctx, "arithmetic-shift: not an integer", i);
  }
  return sexp_bignum_normalize(res);
}

/* bit-count and integer-length were adapted from: */
/* http://graphics.stanford.edu/~seander/bithacks.html */
static sexp_uint_t bit_count (sexp_uint_t i) {
  i -= ((i >> 1) & (sexp_uint_t)~(sexp_uint_t)0/3);
  i = ((i & (sexp_uint_t)~(sexp_uint_t)0/15*3)
       + ((i >> 2) & (sexp_uint_t)~(sexp_uint_t)0/15*3));
  i = (i + (i >> 4)) & (sexp_uint_t)~(sexp_uint_t)0/255*15;
  return ((sexp_uint_t)(i * ((sexp_uint_t)~(sexp_uint_t)0/255))
          >> (sizeof(i) - 1) * CHAR_BIT);
}

static sexp sexp_bit_count (sexp ctx, sexp x) {
  sexp res;
  sexp_sint_t count, i;
  if (sexp_fixnump(x)) {
    i = sexp_unbox_fixnum(x);
    res = sexp_make_fixnum(bit_count(i<0 ? ~i : i));
#if USE_BIGNUMS
  } else if (sexp_bignump(x)) {
    for (i=count=0; i<sexp_bignum_length(x); i++)
      count += bit_count(sexp_bignum_data(x)[i]);
    res = sexp_make_fixnum(count);
#endif
  } else {
    res = sexp_type_exception(ctx, "bit-count: not an integer", x);
  }
  return res;
}

static const char log_table_256[256] = 
{
#define LT(n) n, n, n, n, n, n, n, n, n, n, n, n, n, n, n, n
  0, 1, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4,
  LT(5), LT(6), LT(7), LT(7), LT(7), LT(7), LT(7),
  LT(8), LT(8), LT(8), LT(8), LT(8), LT(8), LT(8), LT(8)
};

static sexp_uint_t integer_log2 (sexp_uint_t x) {
  sexp_uint_t t, tt;
  if ((tt = x >> 32))
    return integer_log2(tt) + 32;
  else if ((tt = x >> 16))
    return (t = tt >> 8) ? 24 + log_table_256[t] : 16 + log_table_256[tt];
  else 
    return (t = x >> 8) ? 8 + log_table_256[t] : log_table_256[x];
}

static sexp sexp_integer_length (sexp ctx, sexp x) {
  sexp_sint_t hi, tmp;
  if (sexp_fixnump(x)) {
    tmp = sexp_unbox_fixnum(x);
    return sexp_make_fixnum(integer_log2(tmp < 0 ? -tmp-1 : tmp));
#if USE_BIGNUMS
  } else if (sexp_bignump(x)) {
    hi = sexp_bignum_hi(x);
    return sexp_make_fixnum(integer_log2(sexp_bignum_data(x)[hi])
                            + hi*sizeof(sexp_uint_t));
#endif
  } else {
    return sexp_type_exception(ctx, "integer-length: not an integer", x);
  }
}

static sexp sexp_bit_set_p (sexp ctx, sexp i, sexp x) {
  sexp_uint_t pos;
  if (! sexp_fixnump(i))
    return sexp_type_exception(ctx, "bit-set?: not an integer", i);
  if (sexp_fixnump(x)) {
    return sexp_make_boolean(sexp_unbox_fixnum(x) & (1<<sexp_unbox_fixnum(i)));
#if USE_BIGNUMS
  } else if (sexp_bignump(x)) {
    pos = sexp_unbox_fixnum(i) / (sizeof(sexp_uint_t)*CHAR_BIT);
    return sexp_make_boolean((pos < sexp_bignum_length(x))
                             && (sexp_bignum_data(x)[pos]
                                 & (1<<(sexp_unbox_fixnum(i)
                                        - pos*sizeof(sexp_uint_t)*CHAR_BIT))));
#endif
  } else {
    return sexp_type_exception(ctx, "bit-set?: not an integer", x);
  }
}

sexp sexp_init_library (sexp ctx, sexp env) {
  sexp_define_foreign(ctx, env, "bit-and",    2, sexp_bit_and);
  sexp_define_foreign(ctx, env, "bit-ior",    2, sexp_bit_ior);
  sexp_define_foreign(ctx, env, "bit-xor",    2, sexp_bit_xor);
  sexp_define_foreign(ctx, env, "arithmetic-shift",  2, sexp_arithmetic_shift);
  sexp_define_foreign(ctx, env, "bit-count",  1, sexp_bit_count);
  sexp_define_foreign(ctx, env, "integer-length",  1, sexp_integer_length);
  sexp_define_foreign(ctx, env, "bit-set?", 2, sexp_bit_set_p);
  return SEXP_VOID;
}
