import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

const _account = 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe';
const _issuer = 'rP9jPyP5kyvFRb6ZiRghAGw5u8SGAmU4bd';
const _otherIssuer = 'rvYAfWj5gh67oV6fW32ZzP3Aw4Eubs59B';
const _auth1 = 'rMBzp8CgpE441cp5PVyA9rpVV7oT8hP3ys';
const _auth2 = 'rDTXLQ7ZKZVKz33zJbHjgVShjsBnqMBhmN';
const String _auth3 = _otherIssuer;
const String _auth4 = _issuer;
const _lpCurrency = '039C99CD9AB0B70B32ECDA51EAAE471625608EA2';
const _lpIssuer = 'rNJSNwbggDhEBwhRXNeyeY7G2Xy3gxLjYH';
const _signingPubKey =
    'ED5F5AC8B98974A3CA843326D9B88CEBD0560177B973EE0B149F782911E5E8A9C1';

const _xrp = XrplAsset.xrp();
final _tst = XrplAsset.issued(currency: 'TST', issuer: _issuer);

/// The pool's LP tokens, as a bid amount.
XrplCurrencyAmount _lp(String value) {
  return XrplCurrencyAmount.issued(
    currency: _lpCurrency,
    issuer: _lpIssuer,
    value: value,
  );
}

XrplAmmBid _bid({
  XrplAsset? asset,
  XrplAsset? asset2,
  XrplCurrencyAmount? bidMin,
  XrplCurrencyAmount? bidMax,
  List<String>? authAccounts,
  int? sequence,
  String? fee,
  int? lastLedgerSequence,
}) {
  return XrplAmmBid(
    account: _account,
    asset: asset ?? _xrp,
    asset2: asset2 ?? _tst,
    bidMin: bidMin,
    bidMax: bidMax,
    authAccounts: authAccounts,
    sequence: sequence,
    fee: fee,
    lastLedgerSequence: lastLedgerSequence,
  );
}

void main() {
  group('XrplAmmBid toJson', () {
    test('a bare bid sends only the account and the pool assets', () {
      expect(_bid().toJson(), {
        'TransactionType': 'AMMBid',
        'Account': _account,
        'Asset': {'currency': 'XRP'},
        'Asset2': {'currency': 'TST', 'issuer': _issuer},
      });
    });

    test('sends BidMin and BidMax as issued-currency amounts', () {
      final json = _bid(bidMin: _lp('5'), bidMax: _lp('100')).toJson();

      expect(json['BidMin'], {
        'currency': _lpCurrency,
        'issuer': _lpIssuer,
        'value': '5',
      });
      expect(json['BidMax'], {
        'currency': _lpCurrency,
        'issuer': _lpIssuer,
        'value': '100',
      });
    });

    test('wraps each authorized account in an AuthAccount object', () {
      final json = _bid(authAccounts: [_auth1, _auth2]).toJson();

      expect(json['AuthAccounts'], [
        {
          'AuthAccount': {'Account': _auth1},
        },
        {
          'AuthAccount': {'Account': _auth2},
        },
      ]);
    });

    test('sends no Flags, because AMMBid has none', () {
      final json = _bid(bidMax: _lp('100')).toJson();

      expect(json.containsKey('Flags'), isFalse);
    });

    test('sequence, fee and lastLedgerSequence are sent only when set', () {
      final bare = _bid().toJson();
      expect(bare.containsKey('Sequence'), isFalse);
      expect(bare.containsKey('Fee'), isFalse);
      expect(bare.containsKey('LastLedgerSequence'), isFalse);

      final filled = _bid(
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      ).toJson();
      expect(filled['Sequence'], 9);
      expect(filled['Fee'], '10');
      expect(filled['LastLedgerSequence'], 102);
    });
  });

  group('XrplAmmBid copyWith', () {
    test('fills sequence, fee and lastLedgerSequence and keeps the rest', () {
      final original = _bid(
        bidMin: _lp('5'),
        bidMax: _lp('100'),
        authAccounts: [_auth1],
      );

      final copy = original.copyWith(
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(copy.sequence, 9);
      expect(copy.fee, '10');
      expect(copy.lastLedgerSequence, 102);
      expect(copy.account, original.account);
      expect(copy.asset, original.asset);
      expect(copy.asset2, original.asset2);
      expect(copy.bidMin, same(original.bidMin));
      expect(copy.bidMax, same(original.bidMax));
      expect(copy.authAccounts, [_auth1]);
    });

    test('does not mutate the original', () {
      final original = _bid()
        ..copyWith(sequence: 9, fee: '10', lastLedgerSequence: 102);

      expect(original.sequence, isNull);
      expect(original.fee, isNull);
      expect(original.lastLedgerSequence, isNull);
    });
  });

  group('XrplAmmBid validation', () {
    test('maxAuthAccounts is 4', () {
      expect(XrplAmmBid.maxAuthAccounts, 4);
    });

    test('rejects a pool whose two assets are the same', () {
      expect(() => _bid(asset: _tst, asset2: _tst), throwsArgumentError);
    });

    test('accepts a pool of two issued assets', () {
      final usd = XrplAsset.issued(currency: 'USD', issuer: _otherIssuer);

      final bid = _bid(asset: usd, bidMax: _lp('100'));

      expect(bid.toJson()['Asset'], {
        'currency': 'USD',
        'issuer': _otherIssuer,
      });
    });

    test('rejects a BidMin in XRP (LP tokens are never XRP)', () {
      expect(
        () => _bid(bidMin: const XrplCurrencyAmount.xrp('1000000')),
        throwsArgumentError,
      );
    });

    test('rejects a BidMax in XRP (LP tokens are never XRP)', () {
      expect(
        () => _bid(bidMax: const XrplCurrencyAmount.xrp('1000000')),
        throwsArgumentError,
      );
    });

    test('rejects a BidMin of zero', () {
      expect(() => _bid(bidMin: _lp('0')), throwsArgumentError);
    });

    test('rejects a negative BidMax', () {
      expect(() => _bid(bidMax: _lp('-1')), throwsArgumentError);
    });

    test('rejects a bid value that is not a number', () {
      expect(() => _bid(bidMax: _lp('abc')), throwsArgumentError);
    });

    test('accepts BidMin and BidMax together', () {
      final bid = _bid(bidMin: _lp('5'), bidMax: _lp('100'));

      expect(bid.bidMin, isNotNull);
      expect(bid.bidMax, isNotNull);
    });

    test('rejects more than four authorized accounts', () {
      expect(
        () => _bid(authAccounts: [_auth1, _auth2, _auth3, _auth4, _account]),
        throwsArgumentError,
      );
    });

    test('accepts exactly four authorized accounts', () {
      final bid = _bid(authAccounts: [_auth1, _auth2, _auth3, _auth4]);

      expect(bid.authAccounts, hasLength(4));
    });

    test('rejects the sending account among the authorized accounts', () {
      expect(
        () => _bid(authAccounts: [_auth1, _account]),
        throwsArgumentError,
      );
    });

    test('accepts an empty list of authorized accounts and sends it', () {
      final json = _bid(authAccounts: const []).toJson();

      expect(json['AuthAccounts'], isEmpty);
    });

    test('keeps its own copy of the authorized accounts', () {
      final source = [_auth1];
      final bid = _bid(authAccounts: source);

      source.add(_auth2);

      expect(bid.authAccounts, [_auth1]);
    });

    test('the authorized accounts cannot be modified afterwards', () {
      final bid = _bid(authAccounts: [_auth1]);

      expect(() => bid.authAccounts!.add(_auth2), throwsUnsupportedError);
    });
  });

  group('XrplAmmBid serialization', () {
    // Every expected hex below was produced by the official xrpl-py
    // binary codec, not by this SDK. They are the same vectors the
    // serializer tests use, here reached through the model.
    Uint8List serialize(XrplAmmBid bid) {
      return XrplTransactionSerializer.serialize({
        ...bid.toJson(),
        'SigningPubKey': _signingPubKey,
      });
    }

    test('a BidMax only bid serializes like the xrpl-py vector', () {
      final bid = _bid(
        bidMax: _lp('100'),
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(bid),
        _hexToBytes(
          '1200272400000009201b0000006668400000000000000a6dd5038d7'
          'ea4c68000039c99cd9ab0b70b32ecda51eaae471625608ea291e5c3'
          'd526d6af03e629efbc0a095613116ea1007321ed5f5ac8b98974a3c'
          'a843326d9b88cebd0560177b973ee0b149f782911e5e8a9c18114f6'
          '67b0ca50cc7709a220b0561b85e53a48461fa803180000000000000'
          '0000000000000000000000000000418000000000000000000000000'
          '5453540000000000f2f97c4301c80d60f86653a319aa7f302c70b83'
          'b',
        ),
      );
    });

    test('BidMin and BidMax together serialize like the xrpl-py vector', () {
      final bid = _bid(
        bidMin: _lp('5'),
        bidMax: _lp('100'),
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(bid),
        _hexToBytes(
          '1200272400000009201b0000006668400000000000000a6cd491c37'
          '937e08000039c99cd9ab0b70b32ecda51eaae471625608ea291e5c3'
          'd526d6af03e629efbc0a095613116ea1006dd5038d7ea4c68000039'
          'c99cd9ab0b70b32ecda51eaae471625608ea291e5c3d526d6af03e6'
          '29efbc0a095613116ea1007321ed5f5ac8b98974a3ca843326d9b88'
          'cebd0560177b973ee0b149f782911e5e8a9c18114f667b0ca50cc77'
          '09a220b0561b85e53a48461fa803180000000000000000000000000'
          '0000000000000000418000000000000000000000000545354000000'
          '0000f2f97c4301c80d60f86653a319aa7f302c70b83b',
        ),
      );
    });

    test('two authorized accounts serialize like the xrpl-py vector', () {
      final bid = _bid(
        authAccounts: [_auth1, _auth2],
        sequence: 9,
        fee: '10',
        lastLedgerSequence: 102,
      );

      expect(
        serialize(bid),
        _hexToBytes(
          '1200272400000009201b0000006668400000000000000a7321ed5f5'
          'ac8b98974a3ca843326d9b88cebd0560177b973ee0b149f782911e5'
          'e8a9c18114f667b0ca50cc7709a220b0561b85e53a48461fa8f019e'
          '01b8114dd76483facdee26e60d8a586bb58d09f27045c46e1e01b81'
          '1488a5a57c829f40f25ea83385bbde6c3d8b4ca082e1f1031800000'
          '0000000000000000000000000000000000004180000000000000000'
          '000000005453540000000000f2f97c4301c80d60f86653a319aa7f3'
          '02c70b83b',
        ),
      );
    });
  });
}
