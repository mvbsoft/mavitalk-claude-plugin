# План впровадження: платформний тулінг MaviTalk

> 🇬🇧 English (виконуваний артефакт для агента): [2026-06-21-mavitalk-platform-tooling.md](2026-06-21-mavitalk-platform-tooling.md)
>
> **Призначення цього файлу:** україномовний компаньйон для рев'ю й затвердження командою. Точні кроки, JSON та тіла скілів (англійською — AI-facing) виконує агент за **англійською** версією. Тут — суть, рішення, governance і опис кожної задачі/скіла зрозумілою мовою.

**Мета:** перетворити плагін `mavitalk` на єдиний глобальний платформний шар для всіх репо MaviTalk — він приносить універсальні «рейки» вайб-кодингу (через залежність від `superpowers`), універсальний MCP (`context7`) і спільні скіли-дисципліни — тоді як кожне репо несе лише свою проектну специфіку + pin, що авто-ставить стек-плагіни й MCP при `git clone`.

**Архітектура (3 шари):** (1) **Глобально `~/.claude/`** — нічого, крім плагіна `mavitalk` (+ суто персональне машинне). (2) **Плагін `mavitalk`** (репо `mvbsoft/mavitalk-claude-plugin`) — спільні скіли + хуки + універсальний MCP, і cross-marketplace залежність від `superpowers`. (3) **Закомічене `.claude/` кожного репо** — проектні скіли + pin у `settings.json` (`extraKnownMarketplaces` + `enabledPlugins`) + закомічений `.mcp.json` (секрети лише через `${ENV}`).

## Глобальні обмеження

- **Назва плагіна:** `mavitalk`. **Маркетплейс:** `mavitalk-claude-plugin` (git: `mvbsoft/mavitalk-claude-plugin`). **Тека стану лишається `.superhelpers/`** — НЕ перейменовувати (живий стан у `mavitalk-agents` і `mavitalk-spectrum`).
- **Джерело правди плагіна:** редагувати лише `plugins/mavitalk/` у репо, ніколи копію в `~/.claude/plugins/cache/...`.
- **Жодних секретів у закомічених файлах.** `.mcp.json` посилається на секрети лише як `${ENV_VAR}`. Зараз у `~/.claude.json` лежить **реальний GitHub-токен у плейнтексті** — він ніколи не потрапляє в репо і має бути **ротований** (Фаза 6).
- **AI-facing файли — англійською.** Тіла скілів, маніфести, план — англ.; українські дзеркала лише там, де репо вже їх має.
- **Скіли — lean:** одна відповідальність, короткий `description`-тригер, конкретний чек-ліст — без води.
- **Дисципліна комітів:** одна задача = один сфокусований коміт; Conventional Commits; **без AI-атрибуції** (конвенція MaviTalk).
- **Гейти валідації:** зміни плагіна мають пройти `claude plugin validate plugins/mavitalk` ТА `sh plugins/mavitalk/tests/run-tests.sh` перед комітом. JSON — `jq empty`.

## Рішення (зведення спірних точок з обох рев'ю)

| # | Питання | Рішення | Чому |
|---|---|---|---|
| D1 | Serena universal чи per-project? | **Per-project** (`.mcp.json` у кожному репо) | Serena індексує конкретну кодову базу — за природою проектна. Universal лише `context7`. |
| D2 | Cap тротла: 20 скрізь чи spectrum=10? | **Дефолт 20 + override через `MAVITALK_AGENT_CAP`** | Тротл обмежує *fan-out агентів*, не ML-обчислення; але лишаємо можливість будь-якому репо знизити. |
| D3 | Обсяг `security-audit` | **be + spectrum + agents** (усі бекенди) | spectrum: вебхуки/HMAC/object-store/ML; agents: subprocess/github/linear/оркестрація — велика поверхня атаки. |
| D4 | 4 персональні глобальні скіли | **Релокувати**: `vercel-react`, `vercel-composition`, `web-design-guidelines` → `mavitalk-fe`; `supabase-postgres` → переробити в plugin-скіл `postgres-best-practices`; оригінали прибрати з `~/.claude/skills/` | Вони стек-специфічні, не універсальні; Supabase не використовується. |
| D5 | Як плагін приносить `superpowers`? | **Cross-marketplace `dependencies`** на `mavitalk`, дозволено через `allowCrossMarketplaceDependenciesOn` | Реалізує «глобально лише mavitalk»; superpowers приходить транзитивно на тому ж scope. Потребує доданого маркетплейсу `superpowers-dev` (враховано в pin'ах). |
| D6 | Стек-плагіни (php-modernization, playwright, chrome-devtools, pyright, security-audit) | **Per-project pin**, НЕ залежності плагіна | Тримає універсальний плагін тонким, без зайвого MCP-шуму в кожному репо. |

## Governance плагіна — захист від «god-plugin»

Скіл/компонент потрапляє в плагін `mavitalk` **лише якщо використовується у ≥2 репо** — або стек-агностична дисципліна (для будь-якого репо), або спільне для стеку, що в кількох репо (напр. `python-conventions` для двох Python-сервісів). Скіл, специфічний для одного репо, живе в `.claude/skills/` того репо, ніколи в плагіні. Переоцінювати при кожному додаванні і періодично: якщо спільний скіл «з'їхав» до одного репо — повернути в репо. Плагін лишається **тонким стабільним платформним шаром** — хуки + крос-cutting дисципліни + універсальний MCP — а не звалищем. Усі скіли цього плану відповідають правилу ≥2 репо.

---

## Фаза 1 — Ядро плагіна: залежність + універсальний MCP

- **Задача 1 — дозволити cross-marketplace залежність.** У `.claude-plugin/marketplace.json` додати top-level ключ `"allowCrossMarketplaceDependenciesOn": ["superpowers-dev"]`. Без цього Claude Code **блокує** залежність на плагін з іншого маркетплейсу. Валідація `jq`, коміт.
- **Задача 2 — оголосити залежність і MCP у плагіні.** У `plugins/mavitalk/.claude-plugin/plugin.json` додати:
  ```json
  "dependencies": [ { "name": "superpowers", "marketplace": "superpowers-dev" } ],
  "mcpServers": { "context7": { "type": "http", "url": "https://mcp.context7.com/mcp" } }
  ```
  Валідація `claude plugin validate` + shell-тести, коміт.
- **Задача 3 — cap тротла з override (D2).** У `plugins/mavitalk/hooks/agent-throttle.sh`: `CAP="${MAVITALK_AGENT_CAP:-20}"` із санітизацією на ціле. Спершу падаючий shell-тест, потім реалізація, тести зелені, коміт.

## Фаза 2 — Спільні скіли-дисципліни плагіна

Кожен скіл — `plugins/mavitalk/skills/<name>/SKILL.md`. Після кожного: `claude plugin validate` + перевірка frontmatter, окремий коміт. Призначення кожного (тіла — англ. в EN-плані):

- **`understand-codebase`** — ПЕРЕД змінами в незнайомому репо: прочитати CLAUDE.md, знайти entry points / архітектуру / тести, скласти карту проекту. Не редагувати наосліп.
- **`architecture-review`** — ПЕРЕД написанням коду: перевірити розміщення логіки, напрям залежностей, шари, bounded contexts, циклічні залежності, анти-патерни.
- **`root-cause-analysis`** — при багу/падінні: **заборона** `if`/`retry`/`sleep`/`try-catch`-заглушки, доки причину не доведено; фікс у причині + регрес-тест.
- **`production-readiness`** — перед merge: observability, логи, метрики, безпека міграцій, rollback, зворотна сумісність, idempotency.
- **`git-discipline`** — гілки/коміти/PR: `master` заборонено, **якщо конвенція репо явно не дозволяє**; Conventional Commits; без AI-атрибуції; гейти перед комітом; ніяких секретів.
- **`authorship-hygiene`** ⭐ *(додано на твою вимогу)* — усе має читатися як робота звичайного інженера-людини: **жодних** слідів, що це робила модель/тул (у комітах, коментарях, доках, PR); **і жодних** кодів тікетів/тасків/кроків плану («Task 12a», «AU 1…12») у коді чи доках — це build-time риштування, план видаляється, а коментар лишається мертвим шумом. Метадані процесу — в PR/Linear, не в коді.
- **`documentation-philosophy`** — куди який факт (CLAUDE.md vs skill vs ADR vs doc vs glossary); доки і код міняються одним комітом.
- **`adr-required`** — на архітектурну зміну (нова залежність/БД/протокол/межа/крос-cutting патерн) — запропонувати ADR `docs/adr/NNNN-*.md`. Рутину не чіпати.
- **`migration-safety`** ⭐ *(додано після 2-го рев'ю)* — найдорожчі аварії від міграцій: expand→migrate→contract; реверсивність; `CONCURRENTLY`; lock-aware порядок; батчевий backfill; читати реальний DDL.
- **`performance-review`** ⭐ *(додано після 2-го рев'ю)* — гарячі шляхи: N+1/seq-scan (EXPLAIN), backpressure Redis Streams, sync-I/O в async, ріст пам'яті, зовнішні виклики. Вимірювати, не вгадувати.
- **`python-conventions`** — спільна база для spectrum+agents: uv, ruff+mypy/pyright strict, async FastAPI/pydantic, hexagonal+import-linter, pytest.
- **`postgres-best-practices`** *(перероблено з Supabase-скіла)* — індекси, EXPLAIN, N+1, безпечні міграції, JSONB, pgvector, пулінг.
- **`modularity-check`** — скопіювати наявний (з spectrum, 4-state verdict), узагальнити; дублі в spectrum/agents прибираються у Фазі 4.
- **`effort-calibration`** ⭐ *(додано на валідації — токен-економія)* — на старті задачі визначити розмір (trivial/small/substantial) і під нього масштабувати зусилля: якість пріоритет (~99%), але −5% якості за −30–50% токенів = ок; right-size агентів (inline замість fan-out), research (лише потрібне), tier верифікації, переюз контексту. На дрібному — діяти прямо.
- **`when-tests-are-owed`** *(виноситься з be в плагін — спільне)* — рішення *коли* потрібні тести (поведінкова зміна ⇒ так; доки/конфіг/стиль ⇒ ні); per-repo `*-test-conventions` кажуть *як*. Дубль у be прибирається у Фазі 4; також флаг: be-шний `research-first-design` тепер перекривається `understand-codebase`+`architecture-review` — кандидат на видалення (рішення власника be).

**Задача 14** — фінальна валідація плагіна, `claude plugin marketplace update` + `install`, **push** репо плагіна (щоб інші машини резолвили `mavitalk`).

## Фаза 3 — Прибирання глобалу + релокація персональних скілів (D4)

- **Задача 15** — перенести `vercel-react-best-practices`, `vercel-composition-patterns`, `web-design-guidelines` у `mavitalk-fe/.claude/skills/` (закомічено, гілка `chore/relocate-fe-skills`).
- **Задача 16** — видалити ці 3 + `supabase-postgres-best-practices` з `~/.claude/skills/` (контент Supabase тепер як plugin-скіл `postgres-best-practices`). Глобальних персональних скілів більше немає.

## Фаза 4 — Per-project pin (settings.json) + MCP (.mcp.json)

Перевірка кожної задачі: `jq empty`; `settings.local.json` лишається в `.gitignore`; `grep` що в `.mcp.json` **немає літеральних секретів** (`ghp_`, плейн-конект-стрінгів).

**Маркетплейси в pin'ах** (усі як `github`): `mavitalk-claude-plugin`→`mvbsoft/mavitalk-claude-plugin`; `superpowers-dev`→`obra/superpowers`; `claude-plugins-official`→`anthropics/claude-plugins-official`; `netresearch-claude-code-marketplace`→`netresearch/claude-code-marketplace`. `superpowers-dev` включаємо скрізь, щоб залежність `mavitalk` резолвилась на свіжій машині.

- **Задача 16b — канонічні MCP-сніпети (анти-drift).** Створити `plugins/mavitalk/docs/mcp-snippets.md` з еталонними **без-секретними** дефініціями `serena`/`github`(`${GITHUB_PERSONAL_ACCESS_TOKEN}`)/`linear-server`/`postgres`(`${<REPO>_DATABASE_URL}`). Правило: змінився виклик спільного сервера — спершу тут, потім ре-синк репо. Генератор — поза скоупом наразі.

- **Задача 17 — `mavitalk-be`** *(злити в наявний settings.json)*: `enabledPlugins` = `mavitalk` + `php-modernization` + `security-audit`; `.mcp.json` = `serena` + `linear-server` + `github`(env) + `postgres`(`${MAVITALK_BE_DATABASE_URL}`). Прибрати локальний `agent-throttle.sh` + його блок у settings. Гілка `chore/platform-pin`.
- **Задача 18 — `mavitalk-fe`**: `enabledPlugins` = `mavitalk` + `chrome-devtools-mcp` + `playwright`; `.mcp.json` = `serena` + `linear-server` + `github`(env).
- **Задача 19 — `mavitalk-spectrum`**: `enabledPlugins` = `mavitalk` + `pyright-lsp` + `security-audit`; `.mcp.json` = `serena` + `postgres`(`${MAVITALK_SPECTRUM_DATABASE_URL}`). Прибрати локальні `agent-throttle.sh` + дубль `modularity-check`.
- **Задача 20 — `mavitalk-agents`** *(закриває геп github/linear)*: `enabledPlugins` = `mavitalk` + `pyright-lsp` + `security-audit`; `.mcp.json` = `serena` + `linear-server` + `github`(env) + `postgres`(`${MAVITALK_AGENTS_DATABASE_URL}`). Прибрати локальні `agent-throttle.sh` + дубль `modularity-check` (лишити `quality.sh`).
- **Задача 21 — один source-of-truth для MCP.** Бекап `~/.claude.json`, потім очистити `mcpServers` для 4 проектних шляхів (`jq`), бо тепер їх несуть закомічені `.mcp.json`.

## Фаза 5 — Нові проектні скіли (bootstrap / test / orchestrator / observability)

Живуть у `.claude/skills/` відповідного репо.

- **Задача 22 — `mavitalk-be`:** `be-bootstrap` (Docker up → міграції → health-check API).
- **Задача 23 — `mavitalk-spectrum`:** `spectrum-bootstrap` (4 ролі через `ROLE`), `spectrum-test-conventions` (pytest+anyio+testcontainers, обов'язкові сценарії), `observability` (structlog+prometheus, без секретів).
- **Задача 24 — `mavitalk-agents`:** `agents-bootstrap`, `agents-test-conventions` (детермінований оркестратор → table-driven тести переходів), `orchestrator-pattern` (state-machine, порти-seam'и, human-gates, межі retry), `observability`.

## Фаза 6 — Верифікація, гігієна секретів, хендоф

- **Задача 25 — ротувати GitHub-токен.** Старий `ghp_…` у плейнтексті в `~/.claude.json` — створити новий PAT, покласти в `GITHUB_PERSONAL_ACCESS_TOKEN` (env/direnv/secret-manager), замінити/прибрати літерал, відкликати старий. Перевірити, що в репо немає літеральних токенів.
- **Задача 26 — E2E верифікація.** Валідувати всі маніфести; симулювати свіжий clone (trust → пропонує `mavitalk` + pin'и, `superpowers` резолвиться як залежність, `claude plugin list --json` без `errors`); підтвердити прибирання (немає локальних `agent-throttle.sh`, немає дублів `modularity-check`, глобальні скіли очищені, проектні `mcpServers` у `~/.claude.json` = `{}`).
- **Задача 27 — push гілок + PR-и.** Для кожного репо запушити гілку, відкрити PR «Adopt MaviTalk platform tooling…»; **не мерджити автоматично** — командне рев'ю.

---

## Корективи від глибокого аудиту (per-repo code review)

Read-only аудит 4 репо **підтвердив, що спільний шар плагіна повний і без дублів**, і дав заземлені правки (нові скіли — у Фазі 5; дві корекції — в Задачах 19–20):

- 🔴 **agents — НЕ додавати `github`/`linear` MCP.** Оркестратор навмисно ганяє хопи з 0-MCP, GitHub — через `gh` CLI, Linear — власним HTTP-транспортом. `.mcp.json` = `serena`+`postgres`.
- 🔴 **spectrum — прибрати `pyright-lsp`.** spectrum на mypy `--strict`; pyright дублює з розбіжностями. Лишити `security-audit`.
- ➕ **be → `be-query-objects`** (raw-SQL у сервісах + inline `::find()` ×6 у policies — N+1, без тестів).
- ➕ **agents → `zero-mcp-enforcement`** (0-MCP load-bearing) + **`run-state-durability`** (стан на ФС, не Postgres).
- ✏️ **Рефайни:** be-test-conventions (юніти на важкі сервіси); fe-api-integration (mock→real чек-ліст 66 ендпоінтів), fe-error-handling (route-level ErrorBoundary + 401→auth:expired тест), fe-test-conventions (інтеграційний шар через MSW); spectrum observability (pull-only Prometheus, без in-process counters), spectrum-test-conventions (worker-loop інтеграційний тест); agents observability (structured logging + trace-id крізь хопи).
- ✅ **Лишити:** `mavitalk-imports` (превентивний); `migration-safety` (зловив реальний баг — HNSW non-concurrent у spectrum); `performance-review` (be/spectrum).
- 📄 **ADR-діри:** be (raw-SQL політика, mongodb.md); spectrum (HNSW/pgvector, multitenancy, pull-only Prometheus); agents (0-MCP політика).

## Підсумкова структура

```
~/.claude/        → лише mavitalk (тягне superpowers + context7)
plugin mavitalk   → 2 робочих + shared-скіли (understand-codebase, architecture-review,
                    root-cause-analysis, production-readiness, git-discipline,
                    documentation-philosophy, adr-required, migration-safety,
                    performance-review, python-conventions, postgres-best-practices,
                    modularity-check) · hooks · context7 MCP · dep: superpowers
be     PHP/Yii2   → pin: php-modernization+security-audit · mcp: serena·postgres·github·linear · +be-bootstrap
fe     React/TS   → pin: chrome-devtools+playwright · mcp: serena·github·linear · +vercel×2·web-design (релок)
spectrum Py/async → pin: pyright+security-audit · mcp: serena·postgres · +bootstrap/test/observability
agents Py/orch    → pin: pyright+security-audit · mcp: serena·github·linear·postgres · +bootstrap/test/orchestrator/observability
```

## Порядок виконання

Фази **незалежно shippable**: Фаза 1–2 (плагін) може приземлитись і використовуватись до Фаз 3–5 (репо). Варіанти: (1) subagent-driven — свіжий субагент на задачу з рев'ю між ними (раджу, старт із Фази 1–2); (2) віддати цей план команді на затвердження (таблиця рішень D1–D6 + governance вже є).
