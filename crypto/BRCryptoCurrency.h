//
//  BRCryptoCurrency.h
//  BRCore
//
//  Created by Ed Gamble on 3/19/19.
//  Copyright © 2019 breadwallet. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#ifndef BRCryptoCurrency_h
#define BRCryptoCurrency_h

#include "BRCryptoBase.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    typedef struct BRCryptoCurrencyRecord *BRCryptoCurrency;

    extern const char *
    cryptoCurrencyGetUids (BRCryptoCurrency currency);

    extern const char *
    cryptoCurrencyGetName (BRCryptoCurrency currency);
    
    extern const char *
    cryptoCurrencyGetCode (BRCryptoCurrency currency);
    
    extern const char *
    cryptoCurrencyGetType (BRCryptoCurrency currency);

    /**
     * Return the currency issuer or NULL if there is none.  For an ERC20-based currency, the
     * issuer will be the Smart Contract Address.
     *
     * @param currency the currency
     *
     *@return the issuer as a string or NULL
     */
    extern const char *
    cryptoCurrencyGetIssuer (BRCryptoCurrency currency);
    
    extern BRCryptoBoolean
    cryptoCurrencyIsIdentical (BRCryptoCurrency c1,
                               BRCryptoCurrency c2);
    
    // initial supply
    // total supply
    
    DECLARE_CRYPTO_GIVE_TAKE (BRCryptoCurrency, cryptoCurrency);
    
#ifdef __cplusplus
}
#endif

#endif /* BRCryptoCurrency_h */
