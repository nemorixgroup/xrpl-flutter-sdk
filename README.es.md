[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-teal.svg)](https://opensource.org/licenses/Apache-2.0)
[![Dart](https://img.shields.io/badge/Dart-3.x-teal.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![CI](https://github.com/nemorixgroup/xrpl-flutter-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/actions)
[![Status](https://img.shields.io/badge/Status-Fase%201%20En%20Progreso-red.svg)](https://github.com/nemorixgroup/xrpl-flutter-sdk/blob/main)  

[English](README.md) | **Español**  

# xrpl_flutter_sdk  

El primer SDK nativo de Flutter/Dart para el XRP Ledger (XRPL).  
Pure Dart · Sin platform channels · Apache 2.0 · pub.dev  

> **Estado: Desarrollo Temprano** - la API aun no es estable.
> Fase actual: Fase 1 - Fundamentos Criptograficos.

Diseñado para ser un **SDK de XRPL abierto y de proposito general**:
pagos, DEX, tokenizacion (NFTs, MPT), escrows, canales de pago, checks
y seguridad de cuenta, todo en un paquete Dart nativo.

## Roadmap (v1.0.0)

| Fase | Foco | Version | Estado |
|------|------|---------|--------|
| 1 | Fundamentos criptograficos (seeds, secp256k1, Ed25519) | `0.1.0-dev` | 🔄 En progreso |
| 2 | Direcciones (classic address, X-address, codec base58 XRPL) | `0.2.0-dev` | ⏳ Planificado |
| 3 | Capa de conexion (WebSocket/JSON-RPC, Mainnet/Testnet/Devnet) | `0.3.0-dev` | ⏳ Planificado |
| 4 | Transacciones core (Payment, TrustSet, sign, submit) | `0.4.0-dev` | ⏳ Planificado |
| 5 | DEX y cross-currency (OfferCreate, AMM, path finding) | `0.5.0-dev` | ⏳ Planificado |
| 6 | Condicionales y canales (Escrow, Payment Channels, Checks) | `0.6.0-dev` | ⏳ Planificado |
| 7 | Tokenizacion (NFTs, MPT, Clawback) | `0.7.0-dev` | ⏳ Planificado |
| 8 | Seguridad de cuenta y compliance (multi-sign, Tickets, Credentials) | `1.0.0` | ⏳ Planificado |

## Documentacion y Knowledge Base

Este SDK esta construido sobre la [XRPL Knowledge Base](https://github.com/nemorixgroup/XRPL-Knowledge-Base), una guia detallada del XRP Ledger que cubre consenso,
arquitectura, servicios nativos y el ecosistema de desarrollo. Lectura
recomendada antes de entrar a los detalles internos del SDK.

## Instalacion

```yaml
# pubspec.yaml
dependencies:
  xrpl_flutter_sdk: ^0.0.1-dev
```

```bash
flutter pub get
```

## Inicio rapido

> La API publica se esta construyendo de forma incremental. Esta
> seccion se actualizara conforme cada fase se complete. Ver la tabla
> de Roadmap arriba para el estado actual.

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
