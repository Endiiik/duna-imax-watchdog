# Duna 3 IMAX watchdog

Hlídá rozpis **Cinema City Praha Flora** a ozve se, když:

- přibude nové promítání **Duny: část třetí v IMAXu**, nebo
- se u už vypsaného promítání **uvolní místa** (práh: aspoň 4 místa
  oproti minulé kontrole; přírůstky po jednom místě se sčítají).

Hlášení přijde jako issue přiřazené vlastníkovi repa, takže GitHub pošle
e-mail i push do mobilní aplikace GitHub. Issue se hned zavírá, slouží jen
jako doručovací kanál.

Běží v GitHub Actions každých ~15 minut, takže funguje i v noci a s vypnutým
počítačem.

## Jak to funguje

- [`watch.py`](watch.py) se ptá veřejného JSON API cinemacity.cz
  (`/cz/data-api-service/v1/quickbook/10101/…`), bez klíče a bez přihlášení.
- API u každého promítání vrací `availabilityRatio` (podíl volných míst).
  Kapacita sálu se z těch poměrů dopočítá sama (IMAX Flora = 385 míst),
  takže hlášení ukazuje konkrétní počty („+3 místa, teď 22 volných z 385“).
  Kde v sále volná místa jsou, API neříká, to je vidět až v mapě sálu.
- Stav (známá promítání a počty volných míst) je v `state/duna3.json`;
  workflow si ho po každé změně commitne zpátky.
- Hlásí se i promítání, která z rozpisu zmizela (zrušená).

## Nastavení (ve `.github/workflows/watch.yml`)

| Proměnná | Výchozí | Význam |
| --- | --- | --- |
| `FILMS` | `duna3:část třetí` | řádky `slug:podřetězec názvu filmu` |
| `AUDITORIUM_PATTERN` | `imax` | podřetězec názvu sálu |
| `MIN_SEAT_DELTA` | `4` | od kolika uvolněných míst hlásit (1 = každé místo) |
| `HALL_CAPACITY` | dopočítá se | kapacitu jde zadat ručně, např. `385` |

## Ruční spuštění

**Actions → Duna 3 IMAX watchdog → Run workflow**. Se zaškrtnutým
*force_report* nahlásí všechny aktuální termíny i s počty volných míst.

## Poznámky

- Repo musí být **veřejné**, jinak běhy čerpají limit 2 000 minut Actions
  měsíčně a 4 běhy za hodinu by ho přečerpaly.
- Až Duna dohraje: Actions → *Disable workflow*.

Vychází z [dualisimo/cinemacity-watchdog](https://github.com/dualisimo/cinemacity-watchdog),
rozšířeno o hlídání uvolněných míst.
