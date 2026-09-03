[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-teal.svg)](https://opensource.org/licenses/Apache-2.0)
[![Dart](https://img.shields.io/badge/Dart-3.x-teal.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![CI](https://github.com/nemorixgroup/xrpl-flutter-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/actions)
[![Status](https://img.shields.io/badge/Status-Fase%202%20Completa-brightgreen.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/blob/main)
[![Status](https://img.shields.io/badge/Status-Fase%204%20En%20Progreso-red.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/blob/main)  

[English](README.md) | **Español**  

# xrpl_flutter_sdk  

El primer SDK nativo de Flutter/Dart para el XRP Ledger (XRPL).  
Dart Puro · Sin platform channels · Apache 2.0 · pub.dev  

> **Estado: Desarrollo Temprano** - la API aun no es estable.  
> Fase 4 (Transacciones core) en progreso. Ver
> [CHANGELOG.md](CHANGELOG.md) para mas detalles.

Diseñado para ser un **SDK de XRPL abierto y de proposito general**:
pagos, DEX, tokenizacion (NFTs, MPT), escrows, canales de pago, checks
y seguridad de cuenta, todo en un paquete Dart nativo.

## Roadmap (v1.0.0)

| Fase | Foco | Version | Estado |
|------|------|---------|--------|
| 1 | Fundamentos criptograficos (seeds, secp256k1, Ed25519) | `0.1.0-dev` | ✅ Completado |
| 2 | Direcciones (classic address, X-address, codec base58 XRPL) | `0.2.0-dev` | ✅ Completado |
| 3 | Capa de conexion (WebSocket/JSON-RPC, Mainnet/Testnet/Devnet) | `0.3.0-dev` | ✅ Completado |
| 4 | Transacciones core (Payment, TrustSet, sign, submit) | `0.4.0-dev` | 🔄 En progreso |
| 5 | DEX y cross-currency (OfferCreate, AMM, path finding) | `0.5.0-dev` | ⏳ Planificado |
| 6 | Condicionales y canales (Escrow, Payment Channels, Checks) | `0.6.0-dev` | ⏳ Planificado |
| 7 | Tokenizacion (NFTs, MPT, Clawback) | `0.7.0-dev` | ⏳ Planificado |
| 8 | Seguridad de cuenta y compliance (multi-sign, Tickets, Credentials) | `1.0.0` | ⏳ Planificado |

## Documentacion y Knowledge Base

Este SDK esta construido sobre la [XRPL Knowledge Base](https://github.com/nemorixgroup/XRPL-Knowledge-Base), una guia detallada del XRP Ledger que cubre consenso,
arquitectura, servicios nativos y el ecosistema de desarrollo. Lectura
recomendada antes de entrar a los detalles internos del SDK.

Cada decisión de implementación detrás de este SDK, incluyendo la elección de bibliotecas, los estándares de codificación y la verificación con respecto a las especificaciones oficiales, está documentada en [docs-sdk/](https://github.com/nemorixgroup/XRPL-Knowledge-Base/tree/main/docs-sdk).

## Instalacion

```yaml
# pubspec.yaml
dependencies:
  xrpl_flutter_sdk: ^0.3.2-dev
```

```bash
flutter pub get
```

## Inicio rapido

```dart
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Genera un nuevo seed. El algoritmo siempre es explicito, nunca se
// infiere, porque el mismo seed produce un par de claves (y una
// direccion) distinta segun el algoritmo usado.
final seed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
print(seed.toBase58()); // ej. "sEdT..."

// Restaura un seed desde un string guardado. El checksum se verifica
// automaticamente; un seed mal escrito o corrupto lanza
// XrplCryptoException en vez de producir datos incorrectos en silencio.
final restored = XrplSeed.fromBase58(seed.toBase58());
print(restored.declaredAlgorithm); // XrplKeyAlgorithm.ed25519
```

```dart
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// secp256k1: derivacion de claves sincrona.
final secpSeed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.secp256k1);
final secpKeys = XrplSecp256k1.deriveKeyPair(secpSeed.entropy);
print(secpKeys.compressedPublicKey); // 33 bytes

// Ed25519: derivacion de claves asincrona (ver docs-sdk/ para el porque).
final edSeed = XrplSeed.generate(algorithm: XrplKeyAlgorithm.ed25519);
final edKeys = await XrplEd25519.deriveKeyPair(edSeed.entropy);
print(edKeys.prefixedPublicKey); // 33 bytes, con prefijo 0xED
```

```dart
import 'package:xrpl_flutter_sdk/xrpl_flutter_sdk.dart';

// Direccion clasica: derivada de una clave publica, reutilizando el
// mismo encoding base58 con checksum que ya usamos para los seeds.
final wallet = await XrplWallet.generate(algorithm: XrplKeyAlgorithm.ed25519);
final address = XrplClassicAddress.deriveFrom(wallet.publicKeyBytes);
print(address); // "r..."
```

```dart
// X-Address: empaqueta cuenta, red, y un destination tag opcional en
// un solo string, para que el tag no se pueda olvidar por separado.
final xAddress = XrplXAddress.deriveFrom(
  wallet.publicKeyBytes,
  network: XrplNetwork.mainnet,
  tag: 12345,
);
print(xAddress); // "X..." (o "T..." para testnet)
```

```dart
// XrplWallet expone su direccion directamente, sin llamada aparte.
final wallet = await XrplWallet.generate(algorithm: XrplKeyAlgorithm.ed25519);
print(wallet.classicAddress); // "r..."
print(wallet.xAddress(network: XrplNetwork.mainnet, tag: 12345)); // "X..."
```

```dart
// Ciclo de vida de la conexion: conectar/desconectar contra un
// servidor real de XRPL. Enviar requests llega en un release posterior.
final connection = XrplConnection(XrplEndpoint.testnet);
await connection.connect();
print(connection.isConnected); // true
await connection.disconnect();
```

```dart
// serverInfo/accountInfo se construyen sobre el metodo generico
// request(), cada uno devolviendo solo la parte util de la respuesta.
final connection = XrplConnection(XrplEndpoint.testnet);
await connection.connect();
final info = await serverInfo(connection);
print(info['server_state']); // ej. "full"
await connection.disconnect();
```

```dart
// Suscribirse a eventos en tiempo real en vez de hacer polling.
await subscribeToLedger(connection);
connection.ledgerEvents.listen((event) {
  print('Nuevo ledger: ${event['ledger_index']}');
});
```

```dart
// Construye una transaccion, y deja que autofill llene Sequence,
// Fee, y LastLedgerSequence automaticamente.
const payment = XrplPayment(
  account: wallet.classicAddress,
  destination: 'rSomeRecipientAddress...',
  amountDrops: '10000000', // 10 XRP
);
final ready = await autofill(connection, payment);
print(ready.fee); // ej. "10"
```

```dart
// Firmar una transaccion: se agregan SigningPubKey y TxnSignature,
// lista para enviarse a la red.
final filled = await autofill(connection, payment);
final signed = await sign(filled.toJson(), wallet);
print(signed['TxnSignature']);
```

## Redes

| Red | URL WebSocket |
|-----|----------------|
| Mainnet | `wss://xrplcluster.com` |
| Testnet | `wss://s.altnet.rippletest.net:51233` |
| Devnet  | `wss://s.devnet.rippletest.net:51233` |

## Contribuciones

El SDK aun no esta listo para contribuciones externas.
Sigue este repositorio para actualizaciones; las contribuciones
seran bienvenidas a partir de la v1.0.0.

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para futuras guias.

## Licencia

Licenciado bajo [Apache 2.0](LICENSE).

## Para desarrolladores en LATAM

Este SDK esta siendo desarrollado con soporte nativo para la region:

- Documentacion bilingue (español / ingles) desde el primer modulo.
- Parte del ecosistema de SDKs de Nemorix Group para infraestructura
  financiera en LATAM (Hedera, Avalanche, XRPL).
- Desarrollado por [Nemorix Group](https://nemorixpay.com), Ohio, USA.

Siguenos para actualizaciones: **sdks@nemorixpay.com**

## Apoya este proyecto

Si este SDK te resulta util a ti o a tu equipo, considera apoyar su
desarrollo. Cada contribucion ayuda a cubrir infraestructura,
documentacion y el tiempo invertido en construir y mantener esta
herramienta open source para la comunidad de XRPL y Flutter. Gracias!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/nemorixgroupllc)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-EA4AAA?logo=github-sponsors&logoColor=white)](https://github.com/sponsors/nemorixgroup)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/nemorixgroupllc)

---

Construido por [Nemorix Group](https://nemorixpay.com) · Apache 2.0
