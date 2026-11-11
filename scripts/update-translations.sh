#!/usr/bin/env bash
# Extracts translatable strings into po/appgroups.pot and merges them into each po/*.po.
# Then compiles po/<lang>.po into package/contents/locale/<lang>/LC_MESSAGES/*.mo.
# Requires gettext (xgettext, msgmerge, msgfmt).
set -euo pipefail
cd "$(dirname "$0")/.."

domain="plasma_applet_io.github.erratos.appgroups"

find package -name '*.qml' | sort | xargs xgettext \
    --from-code=UTF-8 --language=JavaScript \
    --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
    --package-name=plasma-app-groups --msgid-bugs-address=https://github.com/erratos/plasma-app-groups/issues \
    --output=po/appgroups.pot

for po in po/*.po; do
    lang="$(basename "$po" .po)"
    msgmerge --quiet --update --backup=none "$po" po/appgroups.pot
    mkdir -p "package/contents/locale/$lang/LC_MESSAGES"
    msgfmt --check -o "package/contents/locale/$lang/LC_MESSAGES/$domain.mo" "$po"
    echo "$lang: $(msgfmt --statistics -o /dev/null "$po" 2>&1)"
done
