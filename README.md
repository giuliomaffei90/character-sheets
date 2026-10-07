# Schede PNG

Editor per schede di personaggi non giocanti, scritto in Flutter per macOS e Windows: compila i campi,
carica un ritratto (trascina per spostarlo, rotella, pinch o cursore per lo zoom) ed esporta il PDF in stile pergamena.
Le schede si salvano da sole mentre scrivi.

## File
- `lib/main.dart` – l'applicazione.
- `lib/sheet.dart` – disegna il PDF; i campi lasciati vuoti restano compilabili
  (esportando una scheda vuota si ottiene la scheda compilabile da stampare).
- `test/app_test.dart` – controlli sul ritaglio del ritratto e sulla generazione del PDF.

## Avviare da sorgente
Serve [Flutter](https://docs.flutter.dev/get-started/install) 3.47 o successivo:
```
flutter run -d macos     # oppure -d windows
```

## Creare l'eseguibile
Ogni sistema compila il proprio eseguibile:
- **macOS** (serve Xcode): `flutter build macos` → `build/macos/Build/Products/Release/Schede PNG.app`
- **Windows** (serve Visual Studio con "Sviluppo di applicazioni desktop con C++"): `flutter build windows`
  → la cartella `build\windows\x64\runner\Release` (da distribuire per intero).

Il PDF usa Georgia, presente su macOS e Windows, quindi ha lo stesso aspetto su entrambi.

## Scorciatoie
- ⌘N / Ctrl+N – nuovo personaggio
- ⌘E / Ctrl+E – esporta PDF

## Dati
I personaggi salvati sono in `~/SchedePNG/` (un `.json` più l'immagine per ciascuno):
copiando quella cartella si spostano su un altro computer. Il formato è lo stesso della vecchia versione Python.

## Licenza
MIT — vedi [LICENSE](LICENSE).
