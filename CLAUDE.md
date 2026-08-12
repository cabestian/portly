# Portly — règles pour Claude

App macOS Swift (menu-bar + ex-widget) qui liste les ports HTTP locaux.
Repo **public** sur GitHub : `cabestian/portly`.

## Identité git — IMPORTANT

Ce repo a une config locale :
```
user.name  = Cabestian
user.email = 108008243+cabestian@users.noreply.github.com
```

C'est l'email **noreply GitHub** de Cabestian. **Ne jamais le remplacer par `maxime.lhuillier@estp.fr`** lors d'un commit — ce repo est public, l'email perso ne doit pas apparaître publiquement.

Avant tout commit :
```bash
git config user.email   # doit afficher 108008243+cabestian@users.noreply.github.com
```

Si Claude doit forcer une identité (ex: `-c user.email=...`), utiliser uniquement la valeur ci-dessus. En cas de doute, demander à Maxime.

## Build

Pas de Xcode requis — CommandLineTools suffisent :
```bash
bash scripts/build.sh   # produit build/Portly.app
open build/Portly.app
```

Tests :
```bash
cd PortScanCore && swift test
```

## Structure

```
PortlyApp/         — app code (AppDelegate, StatusBarController, ScanRunner, PortListView)
PortScanCore/      — Swift Package (lsof parsing, HTTP probe, name resolver)
scripts/           — build.sh + release.sh
release/           — DMG signés pour release
```
