# Kennis

- [rules.md](rules.md): wat nu geldt, `R-nn`, per regel alleen `Rule:` + `Source:` (Petya's woorden, datum).
- [lessons.md](lessons.md): fouten die nog kunnen gebeuren, `L-nn`, per les `Cause:` + `Fix:`.
- [journal.md](journal.md): een regel per sessie, nieuwste onderaan.

Een sessie leest rules.md en de laatste regels van journal.md voor ze aan de mod werkt.
Toevoegen (controleert daarna met check.py):

    python3 tools/knowledge/learn.py rule "Titel" --rule "..." --source "Petya 2026-11-02: \"...\"" [--group Workflow]
    python3 tools/knowledge/learn.py lesson "Titel" --cause "..." --fix "..." [--rules R-38]
    python3 tools/knowledge/learn.py journal "wat de volgende sessie moet weten"

Een regel die niet meer klopt wordt aangepast of samengevoegd (nieuw vervangt oud, R-46), nooit ernaast gezet.
Oude regels, lessen, gates en scorecard: archief/knowledge-2026-11-02/.
