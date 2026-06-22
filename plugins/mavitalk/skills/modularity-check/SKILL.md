---
name: modularity-check
description: Use when designing any new logic, subsystem, or capability and deciding HOW to structure it — a modular plugin family (registry / plugin / strategy; handler / validator / watcher / notifier / exporter; "add a new kind", "extensible", "open for extension, closed for modification"), a single injected I/O seam (a Protocol mocked for offline tests), or simple direct code (an if/match or a plain function). Advises 🟢 modular family / 🔵 single seam / 🟡 not-yet / 🔴 simple — plain-language reasons, examples, pros, cons, risks — and pushes back BOTH ways (talks the owner out of needless abstraction, or into a clearly-worthwhile one) even on a direct "make it modular". The owner always decides. Triggers at new-feature design, on an extensibility smell, or on request ("design this modularly", "should this be modular?").
---

# Modularity Check — plugin family · single seam · simple code

Decide, at design time, how to structure new logic: a **modular plugin family** (the ADR-005 recipe),
a **single injected I/O seam** (a `Protocol` mocked for offline tests), or **simple direct code** (an
`if`/`match` or a plain function). You only **advise** — the owner always decides.

**Default to simple code.** The costly mistake in this class is *premature abstraction*: the wrong
abstraction welds itself into everything and is far harder to remove than duplication is to dedupe
(Metz). Be primarily a detector of "NO"; recommend a framework only when concrete, present-tense
signals fire. Reason from the signals below — **NOT** "the codebase already has registries/seams."

**Advise, don't obey (both directions).** Even when the owner says "make this modular," run the rubric
first — a request is not a verdict. If a NO detector fires, **push back**: explain plainly why it
would be superfluous here and what it costs; the owner can still override. Conversely, when the
signals clearly hold, make the case confidently ("here it's only upside, because …"). Your value is
honest counsel in **both** directions, never a rubber stamp.

## When this fires (trigger)

- **(A) Always — a one-line check in any new-feature design.** State one explicit line, e.g.
  "modularity here: no — the case set is closed." **Entry filter** — skip even this for trivial /
  data-only / one-shot edits: pure config data, a single parse/format, a one-line fix, renames.
- **(B) Default — on an extensibility smell.** Raise the full rubric when the logic *watches /
  processes / dispatches / validates / exports* **several kinds** of one thing — at design start or
  mid-implementation if the smell surfaces there.
- **(C) On request.** "Design this modularly" / "should this be modular?" → full rubric now (and, on a
  🟢, the ADR-005 recipe). Apply **advise-don't-obey**: run the rubric before complying.

## The rubric — four verdicts

### 🟢 modular family — YES needs all THREE (a conjunction, not any one)
1. **Rule of Three OR a concrete roadmap** — ≥3 real variants of the same shape in hand, OR a
   documented roadmap naming ≥3 specific near-term kinds where the first real implementation already
   exercises the full interface with zero conditionals (so the others reuse it verbatim).
2. **Deep interface** (Ousterhout) — it hides substantially more than it exposes ("is the interface
   simpler than the implementation it hides?"). A trivial one-method wrapper over near-identical
   branches is a *shallow* module → fails.
3. **Single axis of variation** — all variants differ along one dimension behind one honest contract.
   Multiple tangled axes → the abstraction leaks (parameters + `if`-branches).
→ build per the ADR-005 recipe (see "Build recipe & examples").

### 🔵 single I/O seam — a DIFFERENT gate (testability, not extensibility)
When the logic crosses an **I/O / external-world boundary** (network, DB, subprocess, GPU model load,
clock, filesystem, third-party API) and the deterministic core must be **testable offline**: inject a
narrow `Protocol` + a real implementation + a test fake. **One real implementation is correct here** —
this is *not* speculative generality. **Carve-out:** the NO detector "the only user would be a test"
does **NOT** apply to a 🔵 seam — the test fake IS the point (offline determinism); this is exactly the
ADR-005 "test seams" beat (constructor-injected heavy deps). A single impl with no I/O boundary and no
roadmapped family is **not** 🔵 → it's 🔴.

### 🟡 not yet — leave the seam + a revisit trigger
Borderline (1–2 kinds today; might grow). Build simple now, keep a clean boundary, and record a
concrete, checkable trigger to revisit ("when a 2nd engine lands, extract a registry"). The most
common correct early-stage answer — exactly "only where it is really needed *and will really be
extended*." A 🔵 seam often carries a 🟡 trigger (inject now for tests; promote to 🟢 when the 2nd kind
lands). **Default to 🟡/🔴 when unsure** — simple code is easy to change later; the wrong abstraction
is not.

### 🔴 simple code — any one fires → if/match/function
- Fewer than three real implementations and none credibly imminent (a selector would be dead code).
- The extra variants are imagined ("we'll need this someday") — speculative generality; tell-tale: the
  only users of the abstraction would be the tests (UNLESS it's a 🔵 I/O seam — see the carve-out).
- A closed, contract-fixed case set (won't grow to N) — a `match` is clearer.
- Variation is config/parameters into one call, not swappable behavior.
- An input grammar or one-shot transform (parse / validate / compute) — nothing to register.
- A single fixed algorithm/policy, even multi-step — a *consumer*, not a family.
- A 2-branch `default + dict.get` already covers it (a registry owns the open catalog; the call site
  only needs "is this one wired?").

### Deciding tie-breakers
- Need to look a unit up by key later? → registry (🟢). Closed, contract-fixed case set? → `if`/`match` (🔴).
- Crosses an I/O boundary the core must mock to test offline? → seam (🔵).
- Does a unit carry its own config/state/identity in isolation? → family (🟢). Just parameters into one
  shared call? → simple code (🔴).
- One/two kinds now but a real chance of more? → not yet (🟡): simple + a clean seam + a revisit trigger.

### Mechanism (only on a 🟢/🔵)
Use an **explicit declarative registry** (a `*Spec` + a `*Registry` + one `bootstrap` line; no
folder-scanning, no import side-effects) — deterministic, statically checkable (mypy + import-linter),
fails loudly, supports hardcoded priorities. `entry_points`/`importlib.metadata` discovery is **only**
for third-party pip-installed plugins (we have none); it adds a supply-chain attack surface, cold-start
`.dist-info` scanning, and no static enforcement. A 🔵 seam is the same `Protocol`-injection **without**
the registry (one impl). Keep our standard: pure composition in `core`, units inject heavy deps for
test seams, an import-linter independence contract (units never import each other).

## Output — render the advice in Ukrainian (the owner's language)

```
🧩 Перевірка модульності — <назва логіки>

Що це за логіка:        <1 рядок простою мовою>
«Запах розширюваності»: <є / нема> — <що саме тут може бути "кількох видів", чи це межа I/O>

▶ Рекомендація:  🟢 модульна сім'я  /  🔵 один I/O-seam  /  🟡 ще ні — лишаю шов  /  🔴 простий код

Чому (простими словами):  <2–4 речення, без жаргону; на вимогу-модульно — чесно відмов або підтвердь>
Три сигнали YES (для 🟢):  <Rule-of-3/роадмап? · глибокий інтерфейс? · одна вісь?>

Відомі майбутні «споживачі» каркасу:
  • <…>   (або: «жодного на горизонті»)

Якщо зробимо модульно:
  + Плюси:            <що виграємо>
  − Ціна зараз:       <скільки складності/файлів додаємо сьогодні — конкретно>
  ⚠️ Де може вилізти боком: <конкретний ризик/пастка>

Як це житиме далі:   <як власник додаватиме новий елемент — короткий приклад кроків>

Якщо НЕ зараз: додати пізніше буде <дешево / дорого>, бо <…>.
               Сигнал повернутись: <конкретний тригер, напр. "коли з'явиться 2-й вид">

✅ Рішення власника: модульна сім'я / один I/O-seam / ще ні / простий код
```

**Mandatory:** always show **pro AND con AND risk** (never one-sided — even on a 🔴, state what going
modular would cost); always include the "if not now — how painful later + the concrete revisit
trigger" line; the recommendation is yours, the **decision is always the owner's**.

## Common mistakes
- Recommending modular because the codebase already has registries/seams — reason from the signals.
- Flagging a legitimate I/O seam 🔴 because "only a test uses it" — that's the 🔵 carve-out.
- Saying 🔴/🟡 without a revisit trigger ("simple" must not mean "forgotten forever").
- One-sided advice — always include the cost/risk of the path you did NOT recommend.
- Firing the full rubric on a trivial/data-only change — use the one-line check (A) + the entry filter.
- Obeying a "make it modular" request without running the rubric — advise, don't rubber-stamp.
- Deciding for the owner — you advise; present the verdict and let the owner choose.

## Build recipe & examples
- **Build recipe (on a 🟢)** — `docs/architecture/ADR-005-modular-plugin-pattern.md` (the nine-beat
  canonical shape). A 🔵 seam is the same `Protocol`-injection **without** the registry (one impl).
- **Examples** — 🟢 `providers/` · 🔵 single-strategy / test seams · 🟡 deferred families · 🔴
  `parse_retention`: see repo-local `references/examples-from-this-repo.md` if present.
- **Attributed signals + 6 maxims** (Metz, Fowler, Ousterhout, Dodds, Rule of Three):
  see repo-local `references/rubric.md` if present.
