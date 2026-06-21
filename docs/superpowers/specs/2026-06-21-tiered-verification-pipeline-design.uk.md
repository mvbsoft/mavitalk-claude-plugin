# Багаторівневий пайплайн перевірки — дизайн

**Дата:** 2026-06-21
**Компонент:** `plugins/superhelpers/skills/finishing-the-session` (фаза VERIFY)
**Статус:** Затверджений дизайн (ред. 2) — очікує план імплементації

> Англійський файл `2026-06-21-tiered-verification-pipeline-design.md` — канонічний (AI-facing).
> Цей документ — українська копія для власника.

## 1. Проблема й контекст

`finishing-the-session` уже виконує багаторівневе рев'ю свіжим контекстом перед завершенням
сесії (Phase 0 пропозиція рівня → Phase 1 VERIFY → handoff → commit). Поточний дизайн добрий
(детерміновані гейти спершу, subagents зі свіжим контекстом, диференційовані рев'юери,
ізольований Requirement Auditor, Judge із refute-first, Sweep + повторна перевірка на Full).
Цей дизайн закриває розриви з професійною практикою (Greptile/CodeRabbit, стаття Addy Osmani про
agentic-review, дослідження LLM-as-judge і model-cascade) і робить три рівні чистою висхідною
драбиною, яку система пропонує автоматично.

Власник хоче, щоб перевірка надійно ловила: неправильну логіку, баги, відсутню/неповну
документацію, архітектурні проблеми (включно з майбутнім техборгом), неправильну структуру,
погані назви, стиль, якість inline-коментарів, покриття тестами, поламані
контракти/серіалізацію/зворотну сумісність та операційні (production-readiness) дірки — без
того, щоб власнику довелося ловити це згодом самому.

## 2. Цілі / не-цілі

**Цілі**
- Три рівні перевірки (Light / Medium / Full), що відрізняються за *кожним* виміром.
- Система **пропонує** рівень за об'єктивними сигналами + судженням про ризик; фінал — за власником.
- Ширина контексту росте разом із рівнем (найбільший важіль якості для cross-file і
  архітектурних знахідок).
- **Вузькі, одноцільові рев'юери** з явною матрицею «сліпих зон», щоб уникнути дублювання й
  групового мислення.
- **Умовна активація рев'юерів**, щоб Full-прогін піднімав лише рев'юерів, релевантних до того,
  що реально чіпає діф (тримає кількість агентів і вартість пропорційними; потік лишається в межах
  свого self-limit ≤15/вікно, значно нижче 20-агентного hard backstop — див. §15).
- Чітке правило вибору моделі (дешевий retrieval → середнє рев'ю → сильний суддя) + динамічна
  ескалація спірних знахідок.
- Фінальний Judge завжди на Opus.

**Не-цілі**
- Без персистентної інфри code-graph (vector DB / інкрементальний AST-індекс). Повний контекст на
  Full будується щопрогону.
- Без змін у фазах handoff/commit понад те, що в них передає VERIFY.
- Без нових зовнішніх сервісів чи не-Claude моделей.

## 3. Три рівні (повна композиція)

Оцінка ПРОПОНУЄ рівень; власник підтверджує чи перебиває. Substantial-сесія ніколи
само-знижується до пропуску рев'ю.

| Вимір | **LIGHT** (тривіальне) | **MEDIUM** (типове) | **FULL** (суттєве) |
|---|---|---|---|
| Детерміновані гейти | так | так | так + **security-suite ПЕРШИМ** (gitleaks/semgrep/`npm audit`) |
| **Стратегія контексту** | **diff-only** | **impact-map** (1-hop, Haiku) | **повний граф репо** (`wide-impact` для гігантських репо) |
| Рев'юери (активуються за релевантністю) | 2 | до 6 | до 9 |
| Requirement Auditor | ні (inline, у main-потоці) | так (ізольований, Sonnet) | так (ізольований) |
| Sweep (gap-hunt) | ні | ні | так (після базової хвилі) |
| **Judge** | легкий dedup у main-потоці | **Opus** (refute-first) | **Opus** |
| Ескалація знахідок | — | Critical conf < 0.7 / конфлікт → Opus | Critical conf < 0.7 / конфлікт → Opus |
| Після фіксу | re-run гейти | re-run гейти | re-run гейти + **re-review змінених файлів** |
| ≈ токени / прогін | ~80–110k | ~150–250k | ~350–600k (залежить від активованих рев'юерів) |

Контекст росте монотонно: **diff → impact-map(1-hop) → повний граф**. Full за замовчуванням
використовує граф усього репо; на дуже великих репо (~1.5M+ токенів коду) відкочується на
`wide-impact` (2-hop impact-map + сусідні/тестові файли) через конфіг.

## 4. Ростер рев'юерів (меню) і належність до рівнів

Рев'юери вузькі й одноцільові. Кожен рівень бере з цього меню; всередині рівня рев'юер
запускається лише якщо збігається його **умова активації** (див. §6).

| # | Рев'юер | Рівні | Активація | Модель |
|---|---|---|---|---|
| 1 | **Correctness & Edge-cases** | L M F | завжди | Sonnet → Opus (F) |
| 2 | **Quality & Docs** (семантика назв, читабельність, точність inline-коментарів, повнота доків) | L M F | завжди | Haiku (L) / Sonnet |
| 3 | **Architecture** (напрям залежностей, layering, межі) | M F | завжди | Sonnet → Opus (F) |
| 4 | **Maintainability & Change-Risk** (зайва/відсутня абстракція, дублювання, техборг, майбутній coupling, крихкі абстракції, «що зламається через 6 місяців») | F | завжди (F); на M складено в #3 | Sonnet (ескалація до Opus) |
| 5 | **Security** (authn/authz, injection, SSRF, секрети, небезпечна десеріалізація, відсутня валідація) | M F | завжди | Sonnet |
| 6 | **Business-Logic security** (подвійне списання, race conditions, payment abuse, обхід auth-флоу, дірки в state-machine) | F | якщо діф чіпає money / state-machine / auth-флоу; на M складено в #5 | Sonnet |
| 7 | **Data Flow & Contracts** (мапінг DTO, API-контракти, schema evolution, зворотна сумісність, серіалізація/десеріалізація, втрачені поля, міграції) | M F | якщо діф чіпає schema / migration / DTO / serializer / публічний API | Sonnet |
| 8 | **Test-adequacy & Coverage** (чи кожна нова/змінена поведінка осмислено покрита тестами; вироджені assert-и; відсутні edge-тести) | M F | завжди | Sonnet |
| 9 | **Production Readiness** (логування, метрики, tracing, feature flags, стратегія відкату, alertability, error handling) | F | якщо діф чіпає service/handler/infra-код І проєкт має observability-конвенції | Sonnet |

- **Light (2):** Correctness, Quality & Docs.
- **Medium (≤6):** Correctness, Architecture (разом із Maintainability), Security (разом із
  Business-Logic), Quality & Docs, Test-adequacy, Data Flow & Contracts (якщо релевантно).
- **Full (≤9):** меню розщеплене, кожен активується за релевантністю; Correctness + Architecture
  піднято до Opus.

Ростер по рівнях і умови активації **конфігуровані** (§10), тож власник може перекинути перевірку
між рівнями або вимкнути її.

## 5. Матриця «сліпих зон»

Кожному рев'юеру явно сказано, чого він НЕ покриває, щоб рев'юери не дублювалися й не зісковзували
в групове мислення. Додається на початок промпта кожного рев'юера:

```text
correctness:           does_not_review: [architecture, security, style, docs, test design]
quality_docs:          does_not_review: [correctness, security, architecture]
architecture:          does_not_review: [business requirements, code style, test coverage, correctness bugs, abstractions/duplication]
maintainability:       does_not_review: [correctness bugs, security, requirements, style]
security:              does_not_review: [code style, architecture, business-logic abuse (reviewer #6)]
business_logic:        does_not_review: [injection/secrets (reviewer #5), code style, architecture]
data_flow_contracts:   does_not_review: [code style, infra readiness, security]
test_adequacy:         does_not_review: [production-code correctness beyond what tests assert]
production_readiness:  does_not_review: [business correctness, code style, requirements]
requirement_auditor:   does_not_review: [code quality — only requirement↔diff traceability]
```

## 6. Умовна активація рев'юерів

Ростер Full — це меню, а не фіксована хвиля. Активацію керують `touched`-категорії з
`session-signals.sh` + класифікація файлів з impact-map:

- **Business-Logic** ← діф чіпає payment/order/balance/state-machine/auth-flow.
- **Data Flow & Contracts** ← діф чіпає `migration`/`schema`/`.sql`, DTO/serializer-файли або
  публічний API.
- **Production Readiness** ← діф чіпає service/handler/middleware/infra-код І проєкт декларує
  observability-конвенції (`config.yml`), інакше пропускається.
- Рев'юери 1–3, 5, 8 — «завжди» в межах своїх рівнів.

Це тримає Full-прогін пропорційним: чистий рефакторинг внутрішніх хелперів не підніме
Business-Logic, Data Flow чи Production Readiness, тож кількість агентів лишається значно нижче cap.

## 7. Стадії пайплайна й потік даних

```
PHASE 0  TRIAGE (детерміновані факти + судження main-потоку)
  session-signals.sh → факти ─┐
  + судження про ризик ───────┴─→ запропонований рівень → AskUserQuestion → обраний рівень
        │
STAGE 1  DETERMINISTIC GATES        [0 агентів]   red → STOP, фікс, re-run
  test · lint · types · format · coverage-threshold
  (Full: security-suite — gitleaks/semgrep/npm audit — ПЕРШИМ)
  → стиль, naming-convention, форматування, покриття ловляться ТУТ, не LLM-агентами
        │
STAGE 2  CONTEXT BUILD              [Medium+: 1 агент, Haiku]
  Light:  пропущено (diff-only)
  Medium: impact-map (callers/callees/shared modules, 1-hop) + курований список файлів
  Full:   повний граф репо (або wide-impact 2-hop) + класифікація файлів (для активації)
        │
STAGE 3  REVIEW WAVE               [паралельні read-only subagents; лише АКТИВОВАНІ рев'юери]
  ← діф + заявлений scope + курований контекст (НЕ chat history) + рядок «сліпих зон»
  кожен → знахідки: Critical/Important/Minor + file:line + чому + фікс + confidence 0–1
        │
STAGE 3b REQUIREMENT AUDITOR        [Medium+: ізольований, Sonnet]
  ← лише transcript + діф (не виходи рев'юерів) — паралельно зі Stage 3
  → таблиця вимог: DONE / OPEN / UNCERTAIN / SCOPE-CREEP
        │
STAGE 4  SWEEP gap-hunt             [Full: 1 свіжий агент]
  ← діф + дедуплікований список знахідок → до 8 НОВИХ кандидатів (або нічого)
        │
STAGE 5  JUDGE                      [Opus ЗАВЖДИ]
  ← усі знахідки рев'юерів + таблиця аудитора + sweep
  refute-first (цитуй рядок) · soft-drop правило (§8) ·
  Critical conf < 0.7 АБО конфлікт рев'юерів → переадресація на Opus-адʼюдикатор ·
  справжній конфлікт (security-фікс ламає вимогу) → ескалація до власника
  → ОДИН ранжований список (Critical/Important/Minor) + порядок виправлень
        │
STAGE 6  FIX (TDD) → RE-VERIFY
  фікс Critical/Important через TDD → re-run гейти (зелене post-dates останній edit)
  Full: re-review змінених файлів (обмежений reflection-loop)
        │
PHASE 2/3  HAND OFF + COMMIT (без змін)
```

Стадії 3b, 4, 6 секвеновані після базової хвилі, щоб потік лишався в межах self-limit ≤15 на 5-хв
вікно (значно нижче 20-агентного hard backstop; див. §15). Базова хвиля (≤9 рев'юерів + аудитор
≈ 10) вміщається в одне вікно; Sweep і post-fix re-review йдуть у наступному вікні.

## 8. Правила агрегації Judge

- **Refute-first:** для кожної знахідки підтвердь її проти коду, цитуючи точний рядок; ВІДКИНЬ
  знахідки, фактично спростовані (код такого не каже або це захищено деінде).
- **Soft-drop (НЕ жорсткий поріг):** відкидай знахідку, що вижила, ЛИШЕ коли ВСЕ разом: confidence
  < 0.5 **І** піднята одним рев'юером **І** немає верифікованого доказу (немає підтверджувального
  `file:line`, не відтворюється). Інакше — лиши (можливо, знизивши severity). Справжній баг, який
  рев'юер просто недооцінив, зберігається.
- **Ескалюй, а не відкидай, на високих ставках:** будь-який Critical, що вижив, із confidence <
  `escalate_threshold` (0.7), або конфлікт між рев'юерами, переадресується на **Opus-адʼюдикатора**
  перед фінальним ранжуванням.
- **Дедуплікація** знахідок, що перекриваються; матриця «сліпих зон» уже мінімізує перекриття.
- **Справжній конфлікт** (напр., security-фікс ламає заявлену вимогу) → **ескалація до власника**;
  не застосовувати пріоритет мовчки.
- Порядок виправлень: `Security > Requirements > Correctness > Data/Contracts > Architecture/Maintainability > Production-Readiness > Style`.

## 9. Розбір по кроках — рівень FULL

Референс: суттєва бекенд-зміна, що чіпає payment-handler + DTO + міграцію.

**Phase 0 — Triage (0 агентів).** `session-signals.sh` → `files_changed=11, lines_changed=540,
touched=[migration, schema, test]`. Судження про ризик: новий public surface (так), чіпає
payments (так), гейти були зелені (так) → пропонує **Full**. Власник підтверджує.

**Stage 1 — Гейти (0 агентів, детерміновані тули).** Спершу security-suite (gitleaks → semgrep →
`npm audit`), тоді test · lint · types · format · coverage. Числа вставлені. Red → STOP.

**Stage 2 — Побудова контексту (1 агент, Haiku).** Impact-map producer будує граф репо, трасує
callers/callees зміненого payment-handler та producers/consumers DTO, класифікує зачеплені файли
→ активує Business-Logic, Data Flow & Contracts, Production Readiness. Вихід: impact set +
курований список цілих файлів + прапорці активації.

**Stage 3 — Хвиля рев'ю (паралельно; базова хвиля ≤9 рев'юерів + аудитор ≈ 10 вміщається в одне вікно в межах self-limit ≤15). Активовані рев'юери:**

1. **Correctness & Edge-cases** (Opus). Читає: діф + курований контекст. Перевіряє: реальні баги,
   edge-cases, error handling, None/empty/zero, off-by-one, витоки ресурсів, ефективність
   гарячого шляху, contract/shape mismatch. НЕ перевіряє: архітектуру, безпеку, стиль. Повертає:
   ранжовані знахідки + confidence.
2. **Architecture** (Opus). Перевіряє: напрям залежностей, layering, межі модулів, мертвий код.
   НЕ перевіряє: вимоги, стиль, покриття, баги коректності.
3. **Maintainability & Change-Risk** (Sonnet). Перевіряє: зайву/відсутню абстракцію, дублювання,
   техборг, майбутній coupling, крихкі абстракції, «що зламається через 6 місяців». НЕ перевіряє:
   баги коректності, безпеку, вимоги.
4. **Security** (Sonnet). Перевіряє: authn/authz, injection, SSRF, секрети, небезпечну
   десеріалізацію, відсутню валідацію. НЕ перевіряє: business-logic abuse (#6), стиль.
5. **Business-Logic security** (Sonnet) — *активовано*. Перевіряє: подвійне списання, race
   conditions, payment abuse, обхід auth-флоу, дірки state-machine. НЕ перевіряє: injection/секрети (#4).
6. **Data Flow & Contracts** (Sonnet) — *активовано*. Перевіряє: мапінг DTO, втрачені поля, schema
   evolution, зворотну сумісність, серіалізацію/десеріалізацію, безпеку міграцій. НЕ перевіряє:
   стиль, infra readiness.
7. **Quality & Docs** (Sonnet). Перевіряє: семантику назв, читабельність, точність inline-коментарів,
   повноту документації (заявлені-але-відсутні доки = GAP). НЕ перевіряє: коректність, безпеку.
8. **Test-adequacy & Coverage** (Sonnet). Перевіряє: чи нові payment + migration поведінки покриті
   осмисленими тестами; вироджені assert-и; відсутні edge-cases. НЕ перевіряє: коректність
   продакшн-коду поза покриттям.
9. **Production Readiness** (Sonnet) — *активовано*. Перевіряє: логування, метрики, tracing, feature
   flags, стратегію відкату, alertability, error handling на новому шляху. НЕ перевіряє: бізнес-коректність, стиль.

**Stage 3b — Requirement Auditor** (ізольований, Sonnet), паралельно. Читає лише transcript + діф.
Повертає таблицю DONE/OPEN/UNCERTAIN/SCOPE-CREEP.

**Stage 4 — Sweep** (1 свіжий агент), після хвилі. Шукає ЛИШЕ нові дефекти (переміщений код, що
загубив guard, асиметрія setup/teardown, перевернуті config-дефолти). До 8 кандидатів.

**Stage 5 — Judge** (Opus). Refute-first, soft-drop, ескалація спірних Critical на Opus-адʼюдикатора,
ескалація справжніх конфліктів до власника. Один ранжований список + порядок виправлень.

**Stage 6 — Фікс → re-verify.** Фікс Critical/Important через TDD → re-run гейти → re-review
змінених файлів (обмежено).

Light = кроки {1, 7} + гейти + легкий dedup. Medium = {1, 2+3 разом, 4+5 разом, 6 якщо релевантно,
7, 8} + аудитор + Opus-суддя.

## 10. Конфіг (`templates/superhelpers/config.yml`)

```yaml
review:
  default_tier: auto             # auto | light | medium | full
  reviewer_model: sonnet         # базові рев'юери
  retrieval_model: haiku         # impact-map / extraction
  judge_model: opus              # завжди Opus (зафіксовано)
  escalate_model: opus           # адʼюдикатор спірних знахідок
  full_reviewer_escalation: [correctness, architecture]  # підняти до Opus на Full
  full_context: graph            # graph | wide-impact (фолбек для гігантських репо)
  confidence_floor: 0.5          # частина soft-drop правила (§8)
  escalate_threshold: 0.7        # Critical нижче цього → Opus-адʼюдикатор
  max_review_agents: 10        # бюджет базової хвилі (рев'юери + аудитор); вікно в межах self-limit ≤15
  # м'який self-limit на вікно живе під `throttle.self_limit` (єдине джерело)
  rosters:                       # власник може перекинути перевірку між рівнями / вимкнути
    light:  [correctness, quality_docs]
    medium: [correctness, architecture, security, quality_docs, test_adequacy, data_flow_contracts]
    full:   [correctness, architecture, maintainability, security, business_logic,
             data_flow_contracts, quality_docs, test_adequacy, production_readiness]
  activation:                    # умовні рев'юери (пропуск, коли умова хибна)
    business_logic:
      touches: [payment, order, balance, state-machine, auth-flow]
    data_flow_contracts:
      touches: [migration, schema, dto, serializer, public-api]
    production_readiness:
      touches: [service, handler, middleware, infra]
      requires: observability_conventions
throttle:
  hard_cap: 20                 # хук agent-throttle від плагіна (на 5-хв вікно, на сесію)
  self_limit: 15               # верифікація не запускає більше цього на вікно
security:
  deterministic: []              # напр. [gitleaks, semgrep, "npm audit"] — Full, спершу
project:
  observability_conventions: false   # true, якщо проєкт має норми логування/метрик/tracing
```

## 11. Правило вибору моделі

| Робота | Модель |
|---|---|
| Retrieval / трасування / extraction (impact-map, екстракція вимог) | **Haiku** |
| Рев'ю з синтезом/судженням (всі базові рев'юери, аудитор, sweep) | **Sonnet** |
| Full-tier Correctness + Architecture (важка коректність/валідація) | **Opus** |
| Judge (Medium+; Light — main-потоковий dedup) | **Opus** (ізольований Opus-subagent, якщо сесія не на Opus) |
| Адʼюдикація спірних знахідок | **Opus** |

Динамічна ескалація: будь-який Critical із confidence < 0.7, або конфлікт двох рев'юерів,
переадресується на Opus перед фінальним ранжуванням. Лягає на політику моделей машини
(Haiku = retrieval, Sonnet = review, Opus = важка верифікація) і дослідження model-cascade.

## 12. Дельта vs поточна реалізація

- `references/tiers.md` — виміри ризику (auth/payments), мапінг контексту по рівнях, таблиця
  моделей, ростер рев'юерів + умови активації.
- `references/reviewer-prompts.md` — split Architecture → Architecture + Maintainability; split
  Security → Security + Business-Logic; додати Data Flow & Contracts, Test-adequacy, Production
  Readiness; додати impact-map producer; додати рядок «сліпих зон» кожному рев'юеру; зазначити, що
  стиль/naming-convention — це детерміновані гейти; оновити soft-drop правило Judge.
- `references/verification-rubric.md` — вставити Stage 2 (побудова контексту) + умовну активацію +
  крок Opus-адʼюдикатора; зафіксувати Judge = Opus.
- `templates/superhelpers/config.yml` — нові ключі `review:` (rosters, activation, models).
- `hooks/session-signals.sh` — опційно виводити підказки активації (payment/dto/service-шляхи);
  все ще лише факти, судження лишається в скілі.
- `SKILL.md` — відобразити Stage 2, умовну активацію і явне правило Opus-судді.

## 13. Ризики й пом'якшення

- **Кількість агентів vs ліміти** → потік self-limits до ≤15 запущених на 5-хв вікно (пік ~10–11)
  і секвенує решту; хуки `agent-throttle` від плагіна + машинний (CAP 20) — це hard backstop (§15).
- **Вартість Full на великих репо** → фолбек `full_context: wide-impact`.
- **Шум Production Readiness на бібліотеках/CLI** → за `observability_conventions` + активацією
  за шляхами.
- **Тюнінг порога ескалації** → старт 0.7, конфігуровано, перегляд після реальних прогонів.
- **Judge не на Opus, коли сесія на Sonnet** → диспатчити Judge як ізольований Opus-subagent.

## 14. Дослідницька база

- LLM-as-judge: розділення критеріїв між рев'юерами, chain-of-thought, грубе оцінювання,
  self-consistency, пом'якшення біасів, сильніша модель для судді — Patronus, LangChain, огляд
  LLM-as-a-judge.
- Гетерогенність > кількість (93.4% знахідок спіймав рівно один із чотирьох інструментів);
  консенсус для блокування; імовірнісна агрегація confidence — Addy Osmani, *Agentic Code Review*.
- Repo-aware б'є diff-only (82% vs 44% спійманих багів; cross-file трасування) — Greptile.
- Risk-tiered review (підбирати зусилля під вартість помилки; детермінована робота вгору) — Addy
  Osmani; DevOps.com risk-based review.
- Model cascades (дешеве → ескалація на низькій впевненості/розбіжності; економія 45–85%) —
  TianPan, decision-theory paper про каскади.
- Reflection/Reflexion loop для post-fix re-review — agent-patterns, deeplearning.ai.

## 15. Бюджет агентів, throttle і портативність (три шари)

Крок верифікації — єдина частина плагіна, що фанить агентів, тож він обмежений трьома незалежними
шарами (defense in depth), портативними між машинами:

1. **М'який self-limit (логіка скіла).** Потік верифікації ніколи не запускає більше **15 агентів
   на 5-хв вікно** (реальний пік ≈ 10–11: impact-map + базова хвиля + аудитор); решта секвенується
   у наступне вікно. Це забезпечує сам скіл, воно їде з плагіном і працює з хуком чи без — тож потік
   обмежений на будь-якій машині.
2. **Жорсткий backstop, портативний (хук від плагіна).** Плагін постачає PreToolUse-хук
   `agent-throttle` з **CAP=20** на 5-хв вікно на сесію (значення в `config.yml` `throttle.hard_cap`).
   Будь-який проект, що вмикає плагін, отримує його на будь-якій машині — саме це не дає сценарію
   «випадково 100+ агентів на чистій машині», бо їде з увімкненням плагіна, а не живе лише в
   `~/.claude/`. CAP конфігуровний, тож адоптери можуть підкрутити чи вимкнути.
3. **Жорсткий backstop, машинний (особистий `~/.claude/` хук).** CAP=20, ловить scratch/нові
   проекти на цій машині, що НЕ використовують плагін. Machine-local (не їде); ставиш на кожну
   машину сам, як dotfiles.

Шарування: реальний пік ~11 ≤ м'який self-limit 15 ≤ жорсткий backstop 20. Плагіну ніколи не треба
піднімати cap; backstop-и б'ють лише на справжніх runaway. (Імплементація: хук плагіна
`plugins/superhelpers/hooks/agent-throttle.sh`, зареєстрований через плагін, плюс per-project
scaffold, описаний у `references/installing-per-project.md`.)
