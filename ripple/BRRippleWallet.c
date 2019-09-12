//
//  BRRippleWallet.c
//  Core
//
//  Created by Carl Cherry on 5/3/2019.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//  See the CONTRIBUTORS file at the project root for a list of contributors.
//
#include <stdlib.h>
#include <pthread.h>
#include "BRRippleWallet.h"
#include "support/BRArray.h"
#include "BRRipplePrivateStructs.h"
#include <stdio.h>
//
// Wallet
//
struct BRRippleWalletRecord
{
    BRRippleUnitDrops balance; // XRP balance
    BRRippleUnitDrops feeBasis; // Base fee for transactions

    // Ripple account
    BRRippleAccount account;

    BRArrayOf(BRRippleTransfer) transfers;

    pthread_mutex_t lock;
};

extern BRRippleWallet
rippleWalletCreate (BRRippleAccount account)
{
    BRRippleWallet wallet = calloc(1, sizeof(struct BRRippleWalletRecord));
    array_new(wallet->transfers, 0);
    wallet->account = account;
    return wallet;
}

extern void
rippleWalletFree (BRRippleWallet wallet)
{
    if (wallet) {
        array_free(wallet->transfers);
        free(wallet);
    }
}

extern BRRippleAddress
rippleWalletGetSourceAddress (BRRippleWallet wallet)
{
    assert(wallet);
    return rippleAccountGetPrimaryAddress(wallet->account);
}

extern BRRippleAddress
rippleWalletGetTargetAddress (BRRippleWallet wallet)
{
    assert(wallet);
    return rippleAccountGetPrimaryAddress(wallet->account);
}

extern BRRippleUnitDrops
rippleWalletGetBalance (BRRippleWallet wallet)
{
    assert(wallet);
    return wallet->balance;
}

extern void
rippleWalletSetBalance (BRRippleWallet wallet, BRRippleUnitDrops balance)
{
    assert(wallet);
    wallet->balance = balance;
}

extern void rippleWalletSetDefaultFeeBasis (BRRippleWallet wallet, BRRippleUnitDrops feeBasis)
{
    assert(wallet);
    wallet->feeBasis = feeBasis;
}

extern BRRippleUnitDrops rippleWalletGetDefaultFeeBasis (BRRippleWallet wallet)
{
    assert(wallet);
    return wallet->feeBasis;
}

static bool rippleTransferEqual(BRRippleTransfer t1, BRRippleTransfer t2) {
    // Equal means the same transaction id, source, target
    BRRippleTransactionHash hash1 = rippleTransferGetTransactionId(t1);
    BRRippleTransactionHash hash2 = rippleTransferGetTransactionId(t2);
    if (memcmp(hash1.bytes, hash2.bytes, sizeof(hash1.bytes)) == 0) {
        // Hash is the same - compare the source
        BRRippleAddress source1 = rippleTransferGetSource(t1);
        BRRippleAddress source2 = rippleTransferGetSource(t2);
        if (memcmp(source1.bytes, source2.bytes, sizeof(source1.bytes)) == 0) {
            // OK - compare the target
            BRRippleAddress target1 = rippleTransferGetTarget(t1);
            BRRippleAddress target2 = rippleTransferGetTarget(t2);
            if (memcmp(target1.bytes, target2.bytes, sizeof(target1.bytes)) == 0) {
                return true;
            }
        }
    }
    return false;
}

static bool
walletHasTransfer (BRRippleWallet wallet, BRRippleTransfer transfer) {
    bool r = false;
    pthread_mutex_lock (&wallet->lock);
    for (size_t index = 0; index < array_count(wallet->transfers) && false == r; index++) {
        r = rippleTransferEqual (transfer, wallet->transfers[index]);
    }
    pthread_mutex_unlock (&wallet->lock);
    return r;
}

extern void rippleWalletAddTransfer(BRRippleWallet wallet, BRRippleTransfer transfer)
{
    assert(wallet);
    assert(transfer);
    pthread_mutex_lock (&wallet->lock);
    if (!walletHasTransfer(wallet, transfer)) {
        array_add(wallet->transfers, transfer);
        // Update the balance
        BRRippleUnitDrops amount = rippleTransferGetAmount(transfer);
        BRRippleAddress accountAddress = rippleAccountGetAddress(wallet->account);
        BRRippleAddress source = rippleTransferGetSource(transfer);
        if (memcmp(accountAddress.bytes, source.bytes, sizeof(accountAddress.bytes)) == 0) {
            wallet->balance = wallet->balance - amount;
        } else {
            wallet->balance = wallet->balance + amount;
        }
    }
    printf("Ripple balance is %llu\n", wallet->balance);
    pthread_mutex_unlock (&wallet->lock);
    // Now update the balance
}

