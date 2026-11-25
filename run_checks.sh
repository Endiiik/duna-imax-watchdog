#!/usr/bin/env bash
# Několik kontrol rozpisu za sebou v jednom běhu workflow.
#
# Proč: GitHub plánované (cron) běhy u malých repozitářů hodně vynechává —
# místo 4× za hodinu proběhly za 17 hodin jen 3. Proto jeden běh zkontroluje
# rozpis CHECKS× s rozestupem INTERVAL sekund a na konci si sám spustí další
# běh (viz workflow). Cron zůstává jen jako záloha, kdyby se řetěz přerušil.
set -euo pipefail

CHECKS=${CHECKS:-5}
INTERVAL=${INTERVAL:-600}
FORCE=${FORCE_REPORT:-false}

# gh s opakováním — GitHub API občas vrátí 502 (tak selhal běh #4).
gh_retry() {
  local i out
  for i in 1 2 3 4 5; do
    if out=$("$@" 2>&1); then
      printf '%s\n' "$out"
      return 0
    fi
    echo "::warning::gh selhalo (pokus $i/5): $out" >&2
    sleep $((i * 15))
  done
  return 1
}

check_once() {
  local force_flag="" slug pattern report
  [ "$FORCE" = "true" ] && force_flag="--force-report"

  while IFS=: read -r slug pattern; do
    [ -n "$slug" ] || continue
    echo "::group::$slug (film ~ $pattern)"
    FILM_PATTERN="$pattern" python3 watch.py \
      --state "state/$slug.json" \
      --report "report-$slug.md" \
      --title "title-$slug.txt" \
      $force_flag || echo "::warning::Kontrola $slug selhala, zkusí se příště."
    echo "::endgroup::"
  done <<< "$FILMS"

  # Hlášení. Když issue nejde založit, smaže se i rozpracovaný stav daného
  # filmu, takže se novinka nahlásí při další kontrole znovu (neztratí se).
  shopt -s nullglob
  for report in report-*.md; do
    slug=${report#report-}; slug=${slug%.md}
    # Přiřazení vlastníkovi je klíčové: e-mail chodí defaultně jen
    # u "Participating" notifikací (přiřazení, zmínky).
    if url=$(gh_retry gh issue create \
        --title "$(cat "title-$slug.txt")" \
        --body-file "$report" \
        --assignee "$GITHUB_REPOSITORY_OWNER"); then
      echo "Založeno ($slug): $url"
      # Issue je jen doručovací kanál — notifikace odejde při založení.
      gh_retry gh issue close "$url" --reason completed >/dev/null || true
    else
      echo "::error::Issue pro $slug se nepodařilo založit, nahlásí se příště."
      git checkout -- "state/$slug.json" 2>/dev/null || rm -f "state/$slug.json"
    fi
  done
  rm -f report-*.md title-*.txt
  shopt -u nullglob

  # Uložit stav zpátky do repa.
  if [ -n "$(git status --porcelain -- state/)" ]; then
    git add state/
    git commit -q -m "Aktualizace stavu rozpisu ($(date -u '+%Y-%m-%d %H:%M UTC'))"
    for i in 1 2 3 4 5; do
      if git pull --rebase --quiet origin "$GITHUB_REF_NAME" && git push --quiet; then
        echo "Stav uložen."
        return 0
      fi
      sleep $((i * 10))
    done
    echo "::error::Push stavu se nepovedl."
  else
    echo "Stav beze změny."
  fi
}

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for n in $(seq 1 "$CHECKS"); do
  echo "=== Kontrola $n/$CHECKS ($(TZ=Europe/Prague date '+%H:%M'))"
  check_once
  FORCE=false   # vynucené hlášení jen při první kontrole
  if [ "$n" -lt "$CHECKS" ]; then sleep "$INTERVAL"; fi
done
exit 0
