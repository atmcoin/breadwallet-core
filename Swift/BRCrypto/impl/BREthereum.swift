//
//  BREthereum.swift
//  BRCrypto
//
//  Created by Ed Gamble on 3/27/19.
//  Copyright © 2019 breadwallet. All rights reserved.
//

import BRCore.Ethereum
class EthereumNetwork: NetworkBase {
    let core: BREthereumNetwork

    public init (core: BREthereumNetwork,
                 name: String,
                 isMainnet: Bool,
                 currency: Currency,
                 associations: Dictionary<Currency, Association>) {
        self.core = core
        super.init (name: name,
                    isMainnet: isMainnet,
                    currency: currency,
                    associations: associations)
    }
}

///
/// An ERC20 Smart Contract Token
///
public class EthereumToken {

    /// A reference to the Core's BREthereumToken
    internal let identifier: BREthereumToken

    /// The currency
    public let currency: Currency

    /// The address of the token's ERC20 Smart Contract
    public let address: Address

    internal init (identifier: BREthereumToken,
                   currency: Currency) {
        self.identifier = identifier
        self.address = EthereumAddress (tokenGetAddressRaw(identifier))
        self.currency = currency
    }
}

///
/// An EthereumtokenEvent represents a asynchronous announcment of a token's state change.
///
public enum EthereumTokenEvent {
    case created
    case deleted
}

extension EthereumTokenEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .created: return "Created"
        case .deleted: return "Deleted"
        }
    }
}

///
///
///
class EthereumAddress: Address {
    let core: BREthereumAddress

    internal init (_ core: BREthereumAddress) {
        self.core = core
    }

    static func create(string: String, network: Network) -> Address? {
        return (ETHEREUM_BOOLEAN_FALSE == addressValidateString(string)
            ? nil
            : EthereumAddress (addressCreate (string)))
    }

    var description: String {
        return asUTF8String(addressGetEncodedString (core, 1))
    }
}

class EthereumTransfer: Transfer {
    internal let identifier: BREthereumTransfer
    internal var core: BREthereumEWM {
        return _wallet._manager.core!
    }

    /// The EthereumWallet owning this transfer
    public unowned let _wallet: EthereumWallet

    public var wallet: Wallet {
        return _wallet
    }

    internal let unit: Unit

    public private(set) lazy var source: Address? = {
        return EthereumAddress (ewmTransferGetSource (self.core, self.identifier))
    }()

    public private(set) lazy var target: Address? = {
        return EthereumAddress (ewmTransferGetTarget (self.core, self.identifier))
    }()

    public private(set) lazy var amount: Amount = {
        let amount: BREthereumAmount = ewmTransferGetAmount (self.core, self.identifier)
        let value = (AMOUNT_ETHER == amount.type
            ? amount.u.ether.valueInWEI
            : amount.u.tokenQuantity.valueAsInteger)

        return Amount (value: value,
                       isNegative: false,
                       unit: unit)
    } ()

    var fee: Amount

    var feeBasis: TransferFeeBasis

    var hash: TransferHash?

    var state: TransferState

    var isSent: Bool

    

}

///
///
///
class EthereumWallet: Wallet {
    internal let identifier: BREthereumWallet

    public unowned let _manager: EthereumWalletManager

    public var manager: WalletManager {
        return _manager
    }

    private var core: BREthereumEWM {
        return _manager.core!
    }

    public let currency: Currency

    public internal(set) var state: WalletState

    internal init (manager: EthereumWalletManager,
                   currency: Currency,
                   wid: BREthereumWallet) {
        self._manager = manager
        self.identifier = wid
        self.currency = currency
        self.state = WalletState.created
    }
}

///
///
///
class EthereumWalletManager: WalletManager {
    internal var core: BREthereumEWM! = nil

    public let account: Account
    public var network: Network

    public lazy var primaryWallet: Wallet = {
        return EthereumWallet (manager: self,
                               currency: network.currency,
                               wid: ewmGetWallet(self.core))
    }()

    public lazy var wallets: [Wallet] = {
        return [primaryWallet]
    } ()

    internal func addWallet (identifier: BREthereumWallet) {
        guard case .none = findWallet(identifier: identifier) else { return }

        if let tokenId = ewmWalletGetToken (core, identifier) {
            guard let token = findToken (identifier: tokenId) else { precondition(false); return }
            wallets.append (EthereumWallet (manager: self,
                                            currency: token.currency,
                                            wid: identifier))
        }
    }

    internal func findWallet (identifier: BREthereumWallet) -> EthereumWallet? {
        return wallets.first { identifier == ($0 as! EthereumWallet).identifier } as? EthereumWallet
    }

    public var mode: WalletManagerMode

    public var path: String

    public var state: WalletManagerState

    #if false
    public var walletFactory: WalletFactory = EthereumWalletFactory()
    #endif

    internal let query: BlockChainDB

    public init (//listener: EthereumListener,
                 account: Account,
                 network: EthereumNetwork,
                 mode: WalletManagerMode,
                 storagePath: String) {

        self.account = account
        self.network = network
        self.mode    = mode
        self.path    = storagePath
        self.state   = WalletManagerState.created
        self.query   = BlockChainDB()

        self.core = ewmCreate (network.core,
                               account.ethereumAccount,
                               UInt64(account.timestamp),
                               EthereumWalletManager.coreMode (mode),
                               coreEthereumClient,
                               storagePath)

//        EthereumWalletManager.managers.append(Weak (value: self))
//        self.listener.handleManagerEvent(manager: self, event: WalletManagerEvent.created)

    }

    public func connect() {
        ewmConnect (self.core)
    }

    public func disconnect() {
        ewmDisconnect (self.core)
    }

    public func sign (transfer: Transfer, paperKey: String) {
        guard let wallet = primaryWallet as? EthereumWallet,
            let transfer = transfer as? EthereumTransfer else { precondition(false); return }
        ewmWalletSignTransferWithPaperKey(core, wallet.identifier, transfer.identifier, paperKey)
    }

    public func submit (transfer: Transfer) {
        guard let wallet = primaryWallet as? EthereumWallet,
            let transfer = transfer as? EthereumTransfer else { precondition(false); return }
        ewmWalletSubmitTransfer(core, wallet.identifier, transfer.identifier)
    }

    public func sync() {
        ewmSync (core);
    }

    // Actually a Set/Dictionary by {Symbol}
    public private(set) var all: [EthereumToken] = []

    internal func addToken (identifier: BREthereumToken) {
        let symbol = asUTF8String (tokenGetSymbol (identifier))
        if let currency = network.currencyBy (code: symbol) {
            let token = EthereumToken (identifier: identifier, currency: currency)
            all.append (token)
//            self._listener.handleTokenEvent(manager: self, token: token, event: EthereumTokenEvent.created)
        }
    }

    internal func remToken (identifier: BREthereumToken) {
        if let index = all.firstIndex (where: { $0.identifier == identifier}) {
//            let token = all[index]
            all.remove(at: index)
//            self._listener.handleTokenEvent(manager: self, token: token, event: EthereumTokenEvent.deleted)
        }
    }

    internal func findToken (identifier: BREthereumToken) -> EthereumToken? {
        return all.first { $0.identifier == identifier }
    }

    private static func coreMode (_ mode: WalletManagerMode) -> BREthereumMode {
        switch mode {
        case .api_only: return BRD_ONLY
        case .api_with_p2p_submit: return BRD_WITH_P2P_SEND
        case .p2p_with_api_sync: return P2P_WITH_BRD_SYNC
        case .p2p_only: return P2P_ONLY
        }
    }

    private lazy var coreEthereumClient: BREthereumClient = {
        let this = self
        return BREthereumClient (
            context: UnsafeMutableRawPointer (Unmanaged<EthereumWalletManager>.passRetained(this).toOpaque()),

            funcGetBalance: { (context, coreEWM, wid, address, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
                let address = asUTF8String(address!)
                this.query.getBalanceAsETH (ewm: this.core,
                                            wid: wid!,
                                            address: address,
                                            rid: rid) { (wid, balance, rid) in
                                                ewmAnnounceWalletBalance (this.core, wid, balance, rid)
                }},

            funcGetGasPrice: { (context, coreEWM, wid, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        ewm.backendClient.getGasPrice (ewm: ewm,
//                                                       wid: wid!,
//                                                       rid: rid)
//                    }
//                }},
        },
            funcEstimateGas: { (context, coreEWM, wid, tid, from, to, amount, data, rid)  in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
                    let from = asUTF8String(from!)
                    let to = asUTF8String(to!)
                    let amount = asUTF8String(amount!)
                    let data = asUTF8String(data!)
//                    ewm.queue.async {
//                        ewm.backendClient.getGasEstimate(ewm: this.core,
//                                                         wid: wid!,
//                                                         tid: tid!,
//                                                         from: from,
//                                                         to: to,
//                                                         amount: amount,
//                                                         data: data,
//                                                         rid: rid)
//                    }
//                }},
        },

            funcSubmitTransaction: { (context, coreEWM, wid, tid, transaction, rid)  in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
                    let transaction = asUTF8String (transaction!)
//                    ewm.queue.async {
//                        ewm.backendClient.submitTransaction(ewm: ewm,
//                                                            wid: wid!,
//                                                            tid: tid!,
//                                                            rawTransaction: transaction,
//                                                            rid: rid)
//                    }
//                }},
        },
            funcGetTransactions: { (context, coreEWM, address, begBlockNumber, endBlockNumber, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
                    let address = asUTF8String(address!)
//                    ewm.queue.async {
//                        ewm.backendClient.getTransactions(ewm: ewm,
//                                                          address: address,
//                                                          begBlockNumber: begBlockNumber,
//                                                          endBlockNumber: endBlockNumber,
//                                                          rid: rid)
//                    }
//                }},
        },
            funcGetLogs: { (context, coreEWM, contract, address, event, begBlockNumber, endBlockNumber, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
                    let address = asUTF8String(address!)
//                    ewm.queue.async {
//                        ewm.backendClient.getLogs (ewm: ewm,
//                                                   address: address,
//                                                   event: asUTF8String(event!),
//                                                   begBlockNumber: begBlockNumber,
//                                                   endBlockNumber: endBlockNumber,
//                                                   rid: rid)
//                    }
//                }},
        },
            funcGetBlocks: { (context, coreEWM, address, interests, blockStart, blockStop, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
                    let address = asUTF8String(address!)
//                    ewm.queue.async {
//                        ewm.backendClient.getBlocks (ewm: ewm,
//                                                     address: address,
//                                                     interests: interests,
//                                                     blockStart: blockStart,
//                                                     blockStop: blockStop,
//                                                     rid: rid)
//                    }
//                }},
        },
            funcGetTokens: { (context, coreEWM, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        ewm.backendClient.getTokens (ewm: ewm, rid: rid)
//                    }
//                }},
        },
            funcGetBlockNumber: { (context, coreEWM, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        ewm.backendClient.getBlockNumber(ewm: ewm, rid: rid)
//                    }
//                }},
        },

            funcGetNonce: { (context, coreEWM, address, rid) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
                    let address = asUTF8String(address!)
//                    ewm.queue.async {
//                        ewm.backendClient.getNonce(ewm: ewm,
//                                                   address: address,
//                                                   rid: rid)
//                    }
//                }},
        },

            funcEWMEvent: { (context, coreEWM, event, status, message) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        ewm.listener.handleManagerEvent (manager: ewm,
//                                                         event: WalletManagerEvent(event))
//                    }
//                }},
        },
            funcPeerEvent: { (context, coreEWM, event, status, message) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        //                    ewm.listener.handlePeerEvent (ewm: ewm, event: EthereumPeerEvent (event))
//                    }
//                }},
        },
            funcWalletEvent: { (context, coreEWM, wid, event, status, message) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        let event = WalletEvent (ewm: ewm, wid: wid!, event: event)
//                        if case .created = event,
//                            case .none = ewm.findWallet(identifier: wid!) {
//                            ewm.addWallet (identifier: wid!)
//                        }
//
//                        if let wallet = ewm.findWallet (identifier: wid!) {
//                            ewm.listener.handleWalletEvent(manager: ewm,
//                                                           wallet: wallet,
//                                                           event: event)
//                        }
//                    }
//                }},
        },
            funcTokenEvent: { (context, coreEWM, token, event) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        let event = EthereumTokenEvent (event)
//                        if case .created = event,
//                            case .none = ewm.findToken(identifier: token!) {
//                            ewm.addToken (identifier: token!)
//                        }
//
//                        if let token = ewm.findToken(identifier: token!) {
//                            ewm._listener.handleTokenEvent (manager: ewm,
//                                                            token: token,
//                                                            event: event)
//                        }
//                    }
//                }},
        },

            //            funcBlockEvent: { (context, coreEWM, bid, event, status, message) in
            //                if let ewm = EthereumWalletManager.lookup(core: coreEWM) {
            //                    //                    ewm.listener.handleBlockEvent(ewm: ewm,
            //                    //                                                 block: ewm.findBlock(identifier: bid),
            //                    //                                                 event: EthereumBlockEvent (event))
            //                }},

            funcTransferEvent: { (context, coreEWM, wid, tid, event, status, message) in
                let this = Unmanaged<EthereumWalletManager>.fromOpaque(context!).takeRetainedValue()
//                    ewm.queue.async {
//                        if let wallet = ewm.findWallet(identifier: wid!) {
//                            // Create a transfer, if needed.
//                            if (TRANSFER_EVENT_CREATED == event) {
//                                if case .none = wallet.findTransfer(identifier: tid!) {
//                                    wallet.addTransfer (identifier: tid!)
//                                }
//                            }
//
//                            // Prepare a default transferEvent; we'll update this for `event`
//                            var transferEvent: TransferEvent?
//
//                            // Lookup the transfer
//                            if let transfer = wallet.findTransfer(identifier: tid!) {
//                                let oldTransferState = transfer.state
//                                var newTransferState = TransferState.created
//
//                                switch (event) {
//                                case TRANSFER_EVENT_CREATED:
//                                    transferEvent = TransferEvent.created
//                                    break
//
//                                // Transfer State
//                                case TRANSFER_EVENT_SIGNED:
//                                    newTransferState = TransferState.signed
//                                    break
//                                case TRANSFER_EVENT_SUBMITTED:
//                                    newTransferState = TransferState.submitted
//                                    break
//
//                                case TRANSFER_EVENT_INCLUDED:
//                                    let confirmation = TransferConfirmation.init(
//                                        blockNumber: 0,
//                                        transactionIndex: 0,
//                                        timestamp: 0,
//                                        fee: Amount (value: Int(0), unit: wallet.currency.baseUnit))
//                                    newTransferState = TransferState.included(confirmation: confirmation)
//                                    break
//
//                                case TRANSFER_EVENT_ERRORED:
//                                    newTransferState = TransferState.failed(reason: "foo")
//                                    break
//
//                                case TRANSFER_EVENT_GAS_ESTIMATE_UPDATED: break
//                                case TRANSFER_EVENT_BLOCK_CONFIRMATIONS_UPDATED: break
//
//                                case TRANSFER_EVENT_DELETED:
//                                    transferEvent = TransferEvent.deleted
//                                    break
//
//                                default:
//                                    break
//                                }
//
//                                transfer.state = newTransferState
//                                transferEvent = transferEvent ?? TransferEvent.changed(old: oldTransferState, new: newTransferState)
//
//                                // Announce updated transfer
//                                ewm.listener.handleTransferEvent(manager: ewm,
//                                                                 wallet: wallet,
//                                                                 transfer: transfer,
//                                                                 event: transferEvent!)
//                            }
//                        }
//                    }
//                }}
        })
    }()
}