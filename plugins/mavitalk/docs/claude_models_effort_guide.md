# Стандарт вибору моделі Claude + effort

**Статус: офіційний внутрішній довідник компанії.** Джерело істини — документація Anthropic (platform.claude.com/docs), перевірена напряму 2 липня 2026. Розробники та агенти орієнтуються на цей файл при виборі моделі/effort для своєї роботи.

> ⚠️ **Важливе виправлення попередньої версії:** попередній чернетковий варіант цього файлу подавав Sonnet 5 як "новий дефолт для всього". Це **неточно**. Офіційна документація Anthropic прямо каже інше (розділ 1) — Opus 4.8 є рекомендованою відправною точкою для складної агентної розробки, Sonnet 5 — опція для масштабу/швидкості/вартості. Ця версія виправляє помилку.

> ✅ **Журнал верифікації (2 липня 2026, claim-level перевірка A+B).** Цей документ пройшов структуровану перевірку: кожне ключове фактичне твердження звірено з першоджерелом через незалежний веб-пошук (ігноруючи попередній текст файлу), плюс перевірки на внутрішню узгодженість і валідність перехресних посилань. Знайдені й виправлені в цьому проході помилки:
> - **Intelligence Index:** попередня таблиця змішувала дві несумісні версії індексу (v4.0 з релізу Opus 4.8, де Opus=61.4, і v4.1 з Sonnet 5, де Opus≈56, Sonnet 5=53). Розділено явно (розділ 7). Реальний розрив Opus↔Sonnet 5 на одній шкалі — 2-3 пункти, не ~8.
> - **Категоричність твердження про вартість:** "Sonnet 5 дорожчий за Opus" пом'якшено до "на max effort і стандартній ціні" — усунено внутрішню суперечність з уточненням про вступну ціну в тому ж розділі.
> - **Fallback tax:** додано операційне застереження (розділ 11), що ~5% Fable 5-запитів тихо перенаправляються на Opus 4.8 і білінгуються за ставкою Opus.
> - **Хронологія підписки Fable 5:** додано (розділ 11), бракувало деталі про безкоштовне вікно 9-22 червня й перехід на credits з 23 червня.
> - **Підтверджено без змін:** SWE-bench Pro (Opus 4.8=69.2%, Sonnet 5=63.2%, Fable 5=80.3%), вартість Fable 5 за задачу ($5.40 vs $23.70), "Sonnet 5 medium ≈ Sonnet 4.6 high", токенізатор +30%, всі 5 effort-рівнів на всіх моделях включно з Fable 5.
>
> **Що це НЕ гарантує:** частина чисел — vendor-reported (від Anthropic, без незалежного відтворення), позначені відповідно. Джерела датовані днями після релізів і можуть уточнюватись. Абсолютної "остаточної істини" не існує — кожне твердження подано з явним джерелом і рівнем довіри, щоб читач сам бачив, наскільки твердо стоїть факт.

---

## 📋 Зміст

1. [Офіційна позиція Anthropic: з чого починати](#1-офіційна-позиція)
2. [Моделі: технічні характеристики](#2-моделі-технічні-характеристики)
3. [Effort: як це працює технічно](#3-effort-як-це-працює)
4. [Effort-рівні по кожній моделі — офіційні рекомендації](#4-effort-рівні-по-моделях)
5. [Практична матриця: задача → модель → effort](#5-матриця-задача--модель--effort)
6. [Що каже офіційна документація прямим текстом (цитати)](#6-прямі-цитати-з-офіційної-документації)
7. [Незалежний бенчмарк Artificial Analysis — висока довіра](#7-artificial-analysis)
7.5. [Реальна вартість Fable 5 за задачу](#75-реальна-вартість-fable-5-за-задачу--раніше-був-пробіл-у-файлі)
8. [Community-досвід і ризики надійності — середня/нижча довіра](#8-community-досвід)
8.6. [Незалежний польовий тест: 5 effort-рівнів на 12 задачах](#86-незалежний-польовий-тест-5-effort-рівнів-на-12-однакових-кодинг-задачах-найближче-до-прямого-запиту-скільки-токенів-їсть)
9. [Мультиагентна оркестрація: research для планувальника тікетів](#9-мультиагентна-оркестрація)
10. [Практична матриця: задача → модель → effort (оновлена)](#10-оновлена-матриця)
10.5. [Звірка: де сторонні джерела реально доповнюють офіційне](#105-звірка-де-сторонні-джерела-реально-доповнюють-офіційну-документацію-а-де-ні)
11. [Статус доступності Fable 5 / Mythos 5](#11-статус-доступності)
12. [Чек-лист для агента/розробника перед вибором моделі](#12-чек-лист-вибору)
13. [Джерела](#13-джерела)

---

## 1. Офіційна позиція

Пряма цитата з офіційної документації Anthropic (`platform.claude.com/docs/en/about-claude/models/overview`):

> **"If you're unsure which model to use, start with Claude Opus 4.8 for complex agentic coding and enterprise work. For workloads that need the highest available capability, use Claude Fable 5."**

Офіційна матриця вибору моделі (`platform.claude.com/docs/en/about-claude/models/choosing-a-model`):

| Коли потрібно... | Починай з... | Приклади |
|---|---|---|
| Складний агентний кодинг та enterprise-робота | **Claude Opus 4.8** | Multi-hour автономні кодинг-агенти, великомасштабний рефактор, складна системна інженерія, поглиблені дослідження, знання-інтенсивна робота, computer use |
| Frontier-інтелект у масштабі для кодингу, агентів, enterprise-воркфлоу | **Claude Sonnet 5** | Генерація коду, аналіз даних, створення контенту, візуальне розуміння, agentic tool use |
| Near-frontier продуктивність з найшвидшою швидкістю за найекономнішою ціною | **Claude Haiku 4.5** | Real-time застосунки, high-volume обробка, cost-sensitive деплойменти, sub-agent задачі |

Офіційно задокументовано **два підходи** до вибору моделі:

**Підхід 1 — почати з дешевої, швидкої моделі (Haiku 4.5):**
> Найкраще для: початкового прототипування, застосунків з жорсткими вимогами до латентності, cost-sensitive впроваджень, high-volume простих задач.
> Процес: почни з Haiku 4.5 → протестуй на своєму use case → оціни, чи достатньо продуктивності → апгрейдь тільки якщо є конкретний capability gap.

**Підхід 2 — почати з найпотужнішої моделі (Opus 4.8):**
> Найкраще для: складних reasoning-задач, наукових/математичних застосунків, задач, що вимагають нюансованого розуміння, застосунків де точність важливіша за вартість, просунутого кодингу й high-autonomy агентної роботи.
> Процес: впровадь з Opus 4.8 → оптимізуй промпти → оціни продуктивність → з часом підвищуй ефективність зниженням effort або переходом на дешевші моделі.

**Ключовий офіційний висновок:** *"Tuning effort is often a better lever than switching models"* — тюнінг effort часто кращий важіль, ніж заміна моделі.

---

## 2. Моделі: технічні характеристики

Дані напряму з офіційної таблиці порівняння моделей (`platform.claude.com/docs/en/about-claude/models/overview`):

| Характеристика | Claude Fable 5 | Claude Opus 4.8 | Claude Sonnet 5 | Claude Haiku 4.5 |
|---|---|---|---|---|
| **Опис (офіційний)** | Next-generation intelligence for long-running agents | For complex agentic coding and enterprise work | The best combination of speed and intelligence | The fastest model with near-frontier intelligence |
| **API ID** | `claude-fable-5` | `claude-opus-4-8` | `claude-sonnet-5` | `claude-haiku-4-5-20251001` |
| **Ціна вхід/вихід** | $10 / $50 за MTok | $5 / $25 за MTok | $3 / $15 за MTok (інтро $2/$10 до 31.08.2026) | $1 / $5 за MTok |
| **Extended thinking** | Ні | Ні | Ні | **Так** |
| **Adaptive thinking** | Так (завжди увімкнено) | Так | Так | Ні |
| **Відносна латентність** | Повільніша | Помірна | Швидка | Найшвидша |
| **Контекст** | 1M токенів | 1M токенів | 1M токенів | 200K токенів |
| **Макс. вихід** | 128K токенів | 128K токенів | 128K токенів | 64K токенів |
| **Reliable knowledge cutoff** | Січень 2026 | Січень 2026 | Січень 2026 | Лютий 2025 |

> **Важливо:** у таблиці Extended thinking / Adaptive thinking Haiku 4.5 — єдина модель з класичним "extended thinking" (manual budget_tokens), а не adaptive thinking. Sonnet 5, Opus 4.8, Fable 5 керуються через **effort + adaptive thinking**, а не через ручний budget_tokens (цей механізм видалено на цих моделях — повертає `400 error`).

> ⚠️ **Токенізатор — важлива деталь, якої не було в попередній версії файлу.** Офіційна сторінка `platform.claude.com/docs/en/about-claude/pricing` прямо каже:
> *"Claude Opus 4.7 and later Opus models, Claude Fable 5, Claude Mythos 5, Claude Mythos Preview, and Claude Sonnet 5 use a newer tokenizer that contributes to their improved performance on a wide range of tasks. This tokenizer produces approximately 30% more tokens for the same text. Claude Sonnet 4.6 and earlier models use the previous tokenizer."*
>
> **Це критично для правильного трактування порівнянь вартості:** новий токенізатор — це **спільна риса всього поточного покоління** (Sonnet 5, Opus 4.7+, Fable 5, Mythos 5), а не якийсь недолік конкретно Sonnet 5 проти Opus 4.8. Обидві моделі "їдять" на ~30% більше токенів на той самий текст **порівняно зі старими моделями** (Sonnet 4.6 і раніше), але **однаково між собою**. Тобто коли Artificial Analysis (розділ 7) фіксує, що Sonnet 5 витрачає більше токенів на задачу, ніж Opus 4.8, — це **не токенізаторний ефект**, а реальна поведінкова різниця (більше "ходів", довші ланцюги інструментів). Це робить висновок розділу 7 сильнішим, не слабшим: різниця у витраті — це не бухгалтерська різниця в підрахунку токенів, а справжня поведінкова відмінність.
>
> **Практичний наслідок:** якщо твоя команда мігрує промпти/оцінку бюджету зі старих моделей (Sonnet 4.6, Opus 4.6 і раніше) на будь-яку з нових (Sonnet 5, Opus 4.7/4.8, Fable 5) — закладай +30% на той самий текст незалежно від того, яку саме нову модель обираєш. За іншими даними (ADVISORI) інфляція токенів по типу контенту нерівномірна: ~27% для коду, до ~42% для англійської прози.

---

## 3. Effort: як це працює

Офіційне визначення (`platform.claude.com/docs/en/build-with-claude/effort`):

> *"The effort parameter lets you control how eager Claude is about spending tokens when responding to requests. You can trade off between response thoroughness and token efficiency with a single model."*

**Ключові технічні факти (перевірено напряму в офіційній документації):**

- Effort доступний на: Claude Fable 5, Claude Mythos 5, Claude Opus 4.8, Claude Mythos Preview, Claude Opus 4.7, Claude Opus 4.6, **Claude Sonnet 5**, Claude Sonnet 4.6, Claude Opus 4.5.
- **`effort: "high"` — це те саме, що взагалі не передавати параметр** (дефолт на всіх моделях, що його підтримують).
- Effort впливає на **всі токени відповіді**: текстові пояснення, tool calls та їх аргументи, extended/adaptive thinking. Це означає, що навіть без увімкненого thinking, effort все одно контролює кількість tool calls і докладність пояснень.
- Effort — це **поведінковий сигнал, не жорсткий бюджет токенів**. На низькому effort модель все ще думатиме над достатньо складною задачею, але менше, ніж на високому effort для тієї самої задачі.

### П'ять рівнів effort (офіційний опис, дослівно з документації)

| Рівень | Офіційний опис | Типовий use case |
|---|---|---|
| `max` | Абсолютний максимум можливостей без обмежень на витрату токенів | Задачі, що вимагають найглибшого можливого reasoning і найретельнішого аналізу |
| `xhigh` | Розширені можливості для довгострокової роботи. Доступно на Fable 5, Mythos 5, Opus 4.8, Opus 4.7, Sonnet 5 | Довгі агентні й кодинг-задачі (30+ хвилин) з бюджетом токенів у мільйони |
| `high` (дефолт) | Висока продуктивність. Еквівалентно тому, що параметр взагалі не заданий | Складний reasoning, важкі проблеми кодингу, агентні задачі |
| `medium` | Збалансований підхід з помірною економією токенів | Агентні задачі, що потребують балансу швидкості, ціни й продуктивності |
| `low` | Найефективніший. Суттєва економія токенів з деяким зниженням можливостей | Прості задачі, де важливі найкраща швидкість і найнижча ціна, напр. sub-agents |

---

## 4. Effort-рівні по моделях

### Claude Sonnet 5

Офіційна рекомендація (`platform.claude.com/docs/en/build-with-claude/effort`, підтверджено на `prompting-claude-sonnet-5`):

- **High (дефолт):** підходить для складного reasoning, кодингу й агентних задач, де якість важливіша за швидкість чи вартість.
- **Xhigh:** для найважчих кодинг- та агентних задач — офіційно рекомендований рівень для таких задач.
- **Medium:** економний крок вниз від дефолту. **Офіційно порівнюється з Sonnet 4.6 на high** — тобто Sonnet 5 medium ≈ Sonnet 4.6 high за інтелектом.
- **Low:** для high-volume або latency-sensitive навантажень; для чату й некодингових use case, де пріоритет — швидкість.
- **Max:** для задач, що вимагають абсолютно найвищої можливості без обмежень на витрату токенів.

**Офіційне cross-model зіставлення (пряма цитата, для калібрування при міграції):**
> *"As a rough cross-model mapping when migrating: Claude Sonnet 5 at medium is comparable in intelligence to Claude Sonnet 4.6 at high, and Claude Sonnet 5 at high is comparable to Claude Sonnet 4.6 at max."*

**Важлива поведінкова відмінність:** Sonnet 5 **суворо дотримується** effort-рівнів, особливо на нижньому кінці. На `low` і `medium` модель обмежує роботу тим, що було прямо попрошено, не виходячи "за межі запиту". Це добре для латентності й вартості, але на помірно складних задачах на `low` є ризик недостатнього обдумування. Якщо бачиш поверхневий reasoning на складній задачі — **піднімай effort**, а не намагайся обійти промптом.

**На Sonnet 5 adaptive thinking увімкнено за замовчуванням** (на відміну від Sonnet 4.6, де без явного параметра thinking запити йшли без нього). Щоб вимкнути — треба явно передати `thinking: {type: "disabled"}`.

---

### Claude Opus 4.8

Офіційна рекомендація (та сама, що для Opus 4.7 — документація прямо каже "guidance for 4.7 also applies to 4.8"):

> *"Start with xhigh for coding and agentic use cases, use high for most other intelligence-sensitive workloads, and step down to medium or low only when you've measured that the lower level holds quality on your evals."*

- **API-дефолт — `high`**, на всіх поверхнях (API, Claude Code, claude.ai).
- **Xhigh** — офіційно рекомендований **старт** для кодинг- та агентних use case, не high.
- **Max:** може давати приріст продуктивності на деяких задачах, але часто зі спадною віддачею від зростання витрати токенів; може призводити до "overthinking". Тестуй на intelligence-demanding задачах.
- **Medium:** добре для cost-sensitive use case, що потребують зниження витрати токенів ціною інтелекту.
- **Low:** зберігай для коротких, чітко окреслених задач і latency-sensitive навантажень, що не є intelligence-sensitive.

**Важливо для Opus 4.8 (нове порівняно з 4.7):** *"Effort is likely to be more important for this model than for any prior Opus, so experiment with it actively when you upgrade."* — тобто ефект від тюнінгу effort на Opus 4.8 сильніший, ніж на попередніх версіях Opus.

**Recalibration effort-рівнів у 4.8 порівняно з 4.7** (офіційно задокументована зміна): `medium` дозволяє дещо більше thinking, `high` — дещо менше, `xhigh` — суттєво більше. Якщо ти тюнив effort під Opus 4.7 — треба перебазувати вимірювання вартості й латентності при переході на 4.8.

**На Opus 4.8 thinking вимкнено, доки явно не передати `thinking: {type: "adaptive"}`** — на відміну від Sonnet 5, де воно увімкнено за замовчуванням.

---

### Claude Fable 5 (і Mythos 5 — та сама рекомендація)

Офіційна рекомендація (`platform.claude.com/docs/en/build-with-claude/effort`):

> *"Effort is the primary control for trading off intelligence, latency, and cost on Claude Fable 5. Start with high, the default, for most tasks, use xhigh for the most capability-sensitive workloads, and step down to medium or low for routine work. Lower effort settings on Claude Fable 5 still perform well and often exceed xhigh performance on prior models."*

- **High (дефолт)** — для більшості задач.
- **Xhigh** — для найвимогливіших до можливостей навантажень.
- **Medium/Low** — доступні й офіційно рекомендовані для рутинної роботи; важливо: *навіть на низькому effort Fable 5 часто перевершує xhigh попередніх моделей.*
- Adaptive thinking на Fable 5/Mythos 5 **завжди увімкнено** — вимкнути неможливо (`thinking: {type: "disabled"}` відхиляється).
- На `high` і `xhigh` треба виставляти великий `max_tokens` — це жорсткий ліміт на весь вихід (thinking + текст відповіді).

---

### Claude Haiku 4.5

Haiku 4.5 **не має** effort-параметра у тому сенсі, що й Sonnet/Opus/Fable — офіційна документація Anthropic не перелічує Haiku 4.5 серед моделей, що підтримують `effort`. Замість цього Haiku 4.5 керується класичним **extended thinking** (on/off + `budget_tokens`).

Офіційна рекомендація по use case (`platform.claude.com/docs/en/about-claude/models/choosing-a-model`, `ticket-routing`):

> Для ticket routing: *"Many customers have found claude-haiku-4-5-20251001 an ideal model for ticket routing, as it is the fastest and most cost-effective model in the Claude 4 family while still delivering excellent results. If your classification problem requires deep subject matter expertise or a large volume of intent categories complex reasoning, you may opt for the larger Sonnet model."*

---

## 5. Матриця задача → модель → effort

Побудована на основі офіційної моделі "start with cheap OR start with capable" + офіційних effort-рекомендацій вище.

### 🟢 Haiku 4.5 — старт тут для простих/масових/latency-sensitive задач

| Задача | Effort/thinking |
|---|---|
| Класифікація тікетів, роутинг запитів | thinking off (офіційний приклад від Anthropic саме на Haiku) |
| Прості codemod, форматування, перейменування | thinking off |
| Real-time чат-асистенти, sub-agent виконавці | thinking off/мінімальний |
| High-volume обробка з жорсткими вимогами до латентності | thinking off |

**Коли ескалювати вище:** якщо задача класифікації вимагає глибокої предметної експертизи або великої кількості складних intent-категорій → офіційна рекомендація Anthropic — перейти на **Sonnet**.

---

### 🟡 Sonnet 5 — старт тут для frontier-роботи в масштабі

| Задача | Effort |
|---|---|
| Генерація коду, стандартна розробка фіч | `high` (дефолт) |
| Cost-sensitive агентна робота, bulk-обробка | `medium` — офіційно порівнюється з Sonnet 4.6 на high |
| Найважчі кодинг- та агентні задачі в межах Sonnet-рівня | `xhigh` |
| Чат, некодингові задачі, high-volume | `low` |
| Аналіз даних, agentic tool use, visual understanding | `high` |

**Коли ескалювати на Opus:** якщо задача підпадає під офіційну категорію "complex agentic coding and enterprise work" — multi-hour автономні агенти, великомасштабний рефактор, складна системна інженерія — офіційна рекомендація стартувати одразу з **Opus 4.8**, а не намагатись дотягнути Sonnet до потрібного рівня.

---

### 🔴 Opus 4.8 — старт тут для складної агентної/enterprise роботи

| Задача | Effort |
|---|---|
| Multi-hour автономні кодинг-агенти | `xhigh` (офіційний рекомендований старт) |
| Великомасштабний рефактор, складна системна інженерія | `xhigh` |
| Наукові/математичні застосунки, задачі з нюансованим розумінням | `high` мінімум, `xhigh` для складних кейсів |
| Computer use, vision-важкі воркфлоу | `high`/`xhigh` |
| Задачі, де точність важливіша за вартість | `high` мінімум |
| Cost-sensitive задачі всередині Opus-пайплайну | `medium`/`low` — тільки після виміряного підтвердження, що якість тримається |

---

### 🟣 Fable 5 — для найважчих задач у лінійці

| Задача | Effort |
|---|---|
| Задачі, що раніше були занадто складними, довгими або неоднозначними для Opus 4.8 | `high` (дефолт) |
| Найвимогливіші до можливостей навантаження | `xhigh` |
| Рутинна робота (навіть на нижчому effort часто перевершує Opus на xhigh) | `medium`/`low` |

**Офіційне застереження:** Fable 5 не призначений для offensive cybersecurity чи biology/life sciences роботи — такі запити можуть повертати `stop_reason: "refusal"`. Fable 5 запускає safety-класифікатори саме на ці домени; для санкціонованої кібербезпекової роботи офіційна документація рекомендує **Opus 4.8**, а не Sonnet 5 чи Fable 5 (у Sonnet 5 навмисно занижений cyber capability, у Fable 5 — блокуючі класифікатори на offensive-техніки).

---

## 6. Прямі цитати з офіційної документації

Це розділ для швидкої звірки — коли хтось у команді сумнівається в рекомендації файлу, ось точні джерела.

**Про вибір стартової моделі:**
> "If you're unsure which model to use, start with Claude Opus 4.8 for complex agentic coding and enterprise work." — `models/overview`

**Про effort vs заміну моделі:**
> "Tuning effort is often a better lever than switching models." — `about-claude/models/choosing-a-model`

**Про Sonnet 5 medium ≈ Sonnet 4.6 high:**
> "Claude Sonnet 5 at medium is comparable in intelligence to Claude Sonnet 4.6 at high, and Claude Sonnet 5 at high is comparable to Claude Sonnet 4.6 at max." — `prompting-claude-sonnet-5`

**Про Opus 4.8 xhigh як старт для кодингу:**
> "Start with the xhigh effort level for coding and agentic use cases, and use a minimum of high effort for most intelligence-sensitive use cases." — `prompting-claude-opus-4-8`

**Про важливість effort саме на Opus 4.8:**
> "Effort is likely to be more important for this model than for any prior Opus, so experiment with it actively when you upgrade." — `prompting-claude-opus-4-8`

**Про Haiku для ticket routing:**
> "Many customers have found claude-haiku-4-5-20251001 an ideal model for ticket routing, as it is the fastest and most cost-effective model in the Claude 4 family while still delivering excellent results." — `use-case-guides/ticket-routing`

**Про Fable 5 effort:**
> "Lower effort settings on Claude Fable 5 still perform well and often exceed xhigh performance on prior models." — `build-with-claude/effort`

### Зведена таблиця SWE-bench Pro (агентний кодинг) — раніше загублена при переписуванні файлу, відновлено

Числа з системних карток моделей (Anthropic vendor-reported) і фінансово-аналітичних оглядів (finout.io), використовуються далі у файлі (розділ 7.5):

| Модель | SWE-bench Pro |
|---|---|
| Claude Fable 5 | **80.3%** |
| Claude Opus 4.8 | 69.2% |
| Claude Sonnet 5 | 63.2% |
| Claude Sonnet 4.6 | 58.1% |
| GPT-5.5 (для контексту, не Claude) | 58.6% |

⚠️ Це vendor-reported дані (від самого Anthropic, не незалежно відтворені на цьому конкретному бенчмарку), тому трактуй як орієнтир напряму, а не абсолютну істину — на відміну від Artificial Analysis Intelligence Index нижче, який є **незалежним** вимірюванням.

---

## 7. Artificial Analysis

**Artificial Analysis** — незалежна лабораторія бенчмаркінгу моделей. Важливо: **сам Anthropic залучає Artificial Analysis для оцінки своїх моделей перед релізом** ("We supported Anthropic to evaluate Claude Sonnet 5 ahead of release" — це цитата самої Artificial Analysis). Це піднімає довіру до цього джерела вище звичайних редакційних тестів, хоч і нижче за пряму документацію Anthropic.

### Intelligence Index — ⚠️ УВАГА: дві різні версії індексу, які легко переплутати

Artificial Analysis оновлює методологію індексу, і цифри з різних версій **не можна порівнювати напряму**. У попередній версії цього файлу вони були помилково зведені в одну таблицю. Ось коректне розділення (перевірено напряму на artificialanalysis.ai, 2 липня 2026):

**Версія v4.0 (10 евалюацій) — на момент релізу Opus 4.8, 28 травня 2026. Sonnet 5 тоді ще не існував:**

| Модель | Intelligence Index v4.0 | Місце |
|---|---|---|
| Claude Opus 4.8 (max) | **61.4** | #1, +4.1 проти Opus 4.7, +1.2 проти GPT-5.5 (xhigh) |
| GPT-5.5 (xhigh) | 60.2 | #2 |

**Версія v4.1 (9 евалюацій: GDPval-AA v2, τ³-Banking, Terminal-Bench v2.1, SciCode, HLE, GPQA Diamond, CritPt, AA-Omniscience, AA-LCR) — актуальна, включає Sonnet 5 і Fable 5:**

| Модель (max effort) | Intelligence Index v4.1 | Місце |
|---|---|---|
| Claude Fable 5 (max, з Opus 4.8 fallback) | **60** | #1 |
| Claude Opus 4.8 (max) | ~56 | #2 |
| GPT-5.5 (xhigh) | ~55 | #3 |
| Claude Sonnet 5 (max) | **53** | #5, тільки на 2-3 пункти позаду GPT-5.5 (xhigh) і Opus 4.8 (max) |

**Що це означає практично:** число "Opus 4.8 = 61.4" правдиве, але воно зі старішої шкали v4.0 і його **не можна** ставити поруч із "Sonnet 5 = 53" (шкала v4.1) — на одній шкалі v4.1 розрив між Opus 4.8 і Sonnet 5 складає ~3 пункти (56 vs 53), а не ~8. Ключовий висновок від цього не змінюється: Sonnet 5 навіть на max effort стабільно позаду Opus 4.8, але розрив невеликий (2-3 пункти), а не драматичний.

**Найважливіше знахідка Artificial Analysis — реальна вартість за задачу, а не за токен:**

> *"Claude Sonnet 5 costs more per task than Opus 4.8 before accounting for promotional pricing: Claude Sonnet 5 costs $2.29 per task on the Intelligence Index, a ~2x increase compared to Sonnet 4.6 and ~15% more than Claude Opus 4.8. This is driven entirely by increased token usage."*

Тобто **на max effort і стандартній ціні Sonnet 5 виходить дорожчим за Opus 4.8 за фактичну задачу** (при вступній ціні ситуація зворотна — див. уточнення нижче), попри нижчу ставку за токен — бо витрачає значно більше токенів і "ходів" на той самий результат. Важливо: сама Artificial Analysis прямо каже, що цей ефект стосується саме **max effort** ("Sonnet 5 costs $2.29 per task ... at max effort" — FourWeekMBA, що цитує AA), а не всіх рівнів.

> ⚠️ **Критичне уточнення, яке легко пропустити:** цифра $2.29 порахована **на стандартній ціні Sonnet 5 ($3/$15)**, явно позначено "before accounting for promotional pricing". Але **зараз чинна вступна ціна $2/$10** (до 31.08.2026) — це на третину менше. Перерахунок:
>
> Незалежне джерело (digitalapplied.com), що напряму цитує методологію Artificial Analysis, додає ще одне важливе уточнення, якого немає в попередній версії файлу:
> *"Crucially, that is a blended-effort average. At low and medium effort Sonnet 5 stays genuinely cheaper; the inversion only appears at high and max effort."*
>
> Тобто цифра $2.29 — це **усереднення по всіх effort-рівнях**, а не показник, що діє на кожному з них однаково. На low/medium Sonnet 5 залишається дешевшим за Opus 4.8 навіть на стандартній ціні. Інверсія (Sonnet дорожчий) проявляється тільки на high/max effort. Це підтверджує логіку матриці розділу 10, але тепер з прямим цитуванням, а не моєю інтерпретацією.
>
> | Тариф Sonnet 5 | Вартість/задача | Порівняно з Opus 4.8 ($1.99) |
> |---|---|---|
> | Стандартний $3/$15 (з 01.09.2026) | $2.29 | на 15% дорожче |
> | **Вступний $2/$10 (чинний зараз)** | **≈$1.53** | **на ~23% дешевше** |
>
> **Практичний наслідок для стандарту компанії:** до 31 серпня 2026 Sonnet 5 навіть на max effort фактично **дешевший** за Opus 4.8 за задачу — цифра "дорожче на 15%" стане правдивою тільки після переходу на стандартний тариф 1 вересня 2026. Якщо твоя команда читає це до цієї дати — не варто уникати Sonnet 5 xhigh/max через цю цифру. Онови розрахунок після 1 вересня 2026.

**Деталі по токенах (Artificial Analysis):**
> *"With max effort, Sonnet 5 works harder than previous Anthropic models: it used ~40% more output tokens per Intelligence Index task than Sonnet 4.6, and ~3x the agentic turns for our knowledge work evaluations AA-Briefcase and GDPval-AA. This behavior scales well with the 'effort' setting, with the max effort using around 6x more turns than low effort on GDPval-AA."*

**Де Sonnet 5 фактично випереджає Opus 4.8 (важливий нюанс, не тільки "Opus завжди краще"):**
> *"Sonnet 5 matches or outperforms Opus 4.8 on agentic knowledge work tasks: on both AA-Briefcase and GDPval-AA, Claude Sonnet 5 sits just ahead of Opus 4.8, trailing only Claude Fable 5."*

**Практичний висновок з цього розділу:** ефект "Sonnet 5 на xhigh/max може коштувати як Opus 4.8 або дорожче" — **не міф і не поодинокий тест**, а підтверджена незалежною лабораторією закономірність, **але вона правдива тільки на стандартній ціні Sonnet 5 (з 1 вересня 2026)**. За вступною ціною, чинною зараз, ефект зворотний — Sonnet 5 на max дешевший. На **знання-інтенсивних агентних задачах** (не глибокий кодинг, а робота з даними/документами) Sonnet 5 реально попереду Opus 4.8 за якістю незалежно від ціни/тарифу — це окремий, стабільний висновок.

---

## 7.5. Реальна вартість Fable 5 за задачу — раніше був пробіл у файлі

Попередня версія файлу давала рекомендації "коли використовувати Fable 5", але жодних конкретних цифр вартості. Це прогалина, бо Fable 5 — найдорожча модель, і саме тут "золота середина" найчутливіша.

**Ціна за токен:** $10/$50 — вдвічі дорожче за Opus 4.8 ($5/$25), утричі дорожче за Sonnet 4.6 ($3/$15). Але кілька незалежних аналізів (ayautomate.com, developersdigest.tech, finout.io, emergent.sh, digitalapplied.com) сходяться на головному: **ціна за токен — неправильна одиниця виміру для порівняння моделей**. Правильна — ціна за завершену задачу.

### Конкретні виміряні приклади (не гіпотетичні, з польових звітів)

| Сценарій | Opus 4.8 | Fable 5 | Висновок |
|---|---|---|---|
| Async-агент, порівнянна задача | ~$5.40/прогін | ~$23.70/прогін | Розрив $18.30 — виправдано, тільки якщо вихід Fable дійсно merge-ready, а вихід Opus вимагає доробки |
| Задача, де Sonnet 4.6 "закінчує", але результат потребує 2 год доробки людиною | Sonnet 4.6: ~$100 вартості людського часу на доробку (за $50/год) | Fable 5: $4.18 і одразу готово | Тут Fable 5 **дешевший**, попри 17x вищу номінальну ціну за токен — бо людський час дорожчий за токени |
| Batch API (асинхронна обробка, допустима затримка) | $5/$25 (стандартна ставка) | **$5/$25** (Fable 5 у Batch API з 50% знижкою = точно та сама ціна, що й стандартний Opus 4.8) | Пряма арбітражна можливість: Batch API дає можливості рівня Fable/Mythos за ціною Opus 4.8, якщо латентність не критична |

### Де Fable 5 реально виправдовує ціну (за незалежними джерелами)

- **Довгі автономні задачі** (години-дні), де Sonnet/Opus втрачають зв'язність над довгими сесіями
- **Високі ставки на правильність** (фінанси, legal, compliance) — Fable 5 показав найвищий результат на Hebbia's Finance Benchmark; при ціні ~$0.01 за задачу перевірки премія над Sonnet незначна відносно ризику пропущеної помилки
- **SWE-bench Pro для Fable 5: 80.3%** (порівняно з Sonnet 5: 63.2%, Opus 4.8: 69.2% — розділ 6) — суттєвий розрив саме на складному кодингу

### Де Fable 5 НЕ виправдовує ціну (пряме попередження з тих самих джерел)

- **Інтерактивний чат з частими короткими репліками** — 30-хвилинна сесія може легко з'їсти 50K+ токенів; той самий діалог на Sonnet 4.6 коштував би $0.15 замість $2-3 на Fable 5. **Правило:** Sonnet для інтерактивного чату, Fable 5 — для one-shot задач без ітерацій.
- **Задачі, які Opus 4.8 вже впевнено вирішує** (однофайлові правки, прості рефактори, багфікси, документація, рев'ю невеликих PR) — тут Fable 5 коштує вдвічі за маргінальне покращення якості.
- **Задачі, де ти сам ще не визначився, що хочеш** — ітерація дешевша й швидша на Sonnet/Opus; Fable 5 варто застосовувати вже після того, як бриф уточнено.

### Практичний орієнтир від ayautomate.com (одне джерело, але конкретна й перевірювана евристика)

> "Per token, Fable 5 is 2× Opus 4.8 and 3× Sonnet 4.6. Per finished task, the multiplier varies 1×–17× depending on workload and quality requirements. Default to Sonnet 4.6, escalate to Opus 4.8 for hard tasks, reach for Fable 5 when the assignment would otherwise warrant a senior contractor."

Це узгоджується з логікою офіційної документації (розділ 1 — два підходи "почни з дешевої" / "почни з потужної"), просто додає третю сходинку в драбину.

### Операційна деталь про доступ через підписку (актуально на момент написання)

Кілька джерел (emergent.sh, finout.io) фіксують: Fable 5 на підписках (Pro/Max/Team) рахується проти місячного ліміту приблизно **вдвічі агресивніше**, ніж Opus 4.8. Якщо команда сидить на Max-підписці й активно ганяє Fable 5 — ліміт може вичерпатись задовго до кінця місяця; система автоматично перемикає на Sonnet, коли ліміт вичерпано. Для передбачуваного продакшн-навантаження API з явним роутингом (Sonnet за замовчуванням → Opus для складного → Fable для найважчого) — надійніший за підписку.

---

## 8. Community-досвід

**Рівень довіри: середній/нижчий.** Це анекдотичні звіти з Hacker News, Reddit та блогів окремих розробників — корисні для розуміння реальних патернів використання й ризиків, але не статистично надійні дані.

### 8.1. Effort — люди на практиці рідко його чіпають

Пряма цитата з треду на Hacker News про запуск Sonnet 5 (news.ycombinator.com/item?id=48736605):

> *"In practice, I tend to just use the default on Claude Code that works well enough... I'm not going to play around with thinking level every request because the goal is to make me save time not spend it in a different setting menu."*

**Практичний висновок:** попри детальні офіційні рекомендації по effort-рівнях, більшість розробників у продакшн-використанні **не тюнить effort вручну на кожен запит** — покладаються на дефолти. Це аргумент на користь того, щоб твоя команда/агенти мали **заздалегідь прописані effort-налаштування в конфігах/subagent YAML**, а не покладались на ручний вибір під час роботи.

### 8.2. Мішана реакція на "агентність" Sonnet 5

З того самого HN-треду, коментар з протилежним досвідом:

> *"I have been using Sonnet 4.6 more than Opus, because I'm mostly doing agent-assisted development and not fully agent-driven development. This announcement does not make me positive, I have found that the more models are optimized for fully agentic development, the worse they get at assisted development... I have been moving more and more to K2.7 Code and GLM-5.2 the last few weeks."*

**Важливий сигнал:** не всі команди хочуть максимальну "агентність" — якщо твій воркфлоу передбачає покрокову співпрацю з людиною (а не повну автономію), більш "агентна" модель може поводитись гірше (робити забагато без питань), а не краще.

### 8.3. Ризик деградації продуктивності моделі з часом (важливо для стандарту компанії)

Це найважливіша знахідка розділу для внутрішнього стандарту компанії. У лютому-березні 2026 Anthropic **непублічно** знизила дефолтний effort на Opus 4.6 (з "адаптивного" на конкретний рівень, за словами Claude Code lead Бориса Черни) без явного анонсу — і користувачі відчули це як "модель раптом почала гірше думати":

> *"On March 3, the default effort level was dropped to 'medium'... The developer experience, according to a lot of people who wrote about it, felt like the model suddenly 'thought less' and produced worse work. One person described it as 'dumber than Sonnet 3.5.'"*

> *"Pro users on Cowork and Claude Desktop couldn't even change the default — only Claude Code terminal users could manually type /effort high to get the full reasoning back."*

**Це прямо стосується твого стандарту компанії:** якщо агенти й розробники покладаються на "дефолтний effort", а Anthropic тихо змінює дефолти (що вже траплялось), продуктивність системи може непередбачувано впасти без жодних змін з вашого боку. **Висновок: прописуй effort явно в конфігах, не покладайся на дефолт.**

**Другий, окремий, документально підтверджений приклад того самого патерна (Opus 4.7 → 4.8):** незалежні джерела (apiyi.com, claudefa.st) фіксують, що **дефолт effort у Claude Code** (не в самому API — там дефолт завжди `high`) для Opus 4.7 фактично дорівнював `xhigh`:

> *"With the upgrade to Opus 4.7, Claude Code has adjusted its built-in default effort level from high to xhigh. This means that if you simply run the claude command to enter interactive mode, your requests are already using xhigh by default."*

А з релізом Opus 4.8 дефолт у Claude Code повернули назад на `high`:

> *"Opus 4.8 defaults to high effort in Claude Code, where Opus 4.7 defaulted to xhigh."* (claudefa.st)

Технічно це не порушення API-контракту (API-дефолт завжди залишався `high` для обох версій — розділ 4), а зміна саме **інтерактивного дефолту Claude Code**, обґрунтована тим, що high на 4.8 ≈ xhigh на 4.7 за якістю, але дешевше. Але для команди, яка не стежить за реліз-нотатками, це виглядає так само, як інцидент з Opus 4.6 вище: "раптом" змінилась поведінка й вартість запитів без зміни коду. **Це другий незалежний приклад того самого системного ризику — прописаний effort рятує від обох сценаріїв.**

### 8.4. Token burn — реальний фінансовий ризик

Медіум-огляд Opus 4.8 (Barnacle Goose) наводить конкретний кейс:

> *"One widely shared report described a pipeline burning 62 million tokens in 24 hours and draining a $2,500 monthly budget in a single day."*

Причина — комбінація adaptive thinking на дефолтному High effort + паралельні саб-агенти (Dynamic Workflows) без обмежень. **Рекомендація з цього ж джерела:** якщо модель "занадто ретельна" й не зливає результати саб-агентів вчасно — **свідомо знижуй effort до Medium/Low**, це не завжди контрінтуїтивно погана ідея.

### 8.5. Reddit — змішані, але кластеризовані відгуки на Opus 4.8

Зведення з незалежного огляду (claudeai.dev), що агрегував Reddit-фідбек:

> *"The positive reports cluster around large, multi-step work... The negative reports cluster around turn-by-turn reliability and small one-shot tasks. Users reported cases where Opus 4.8 missed an obvious instruction in a planning document, answered a narrow slice of the user's goal instead of the whole goal, or performed worse than 4.7 on simple UI generation prompts."*

**Практичний висновок:** підтверджує офіційну логіку "Opus для складних multi-step задач", але додає нюанс — **на простих одноразових задачах Opus 4.8 не завжди кращий** за попередню версію чи навіть за дешевшу модель. Це аргумент проти "Opus за замовчуванням на все".

---

### 8.6. Незалежний польовий тест: 5 effort-рівнів на 12 однакових кодинг-задачах (найближче до прямого запиту "скільки токенів їсть")

Автор Chew Loong Nian (Towards AI) прогнав **однакові 12 кодинг-задач** через усі 5 effort-рівнів Opus 4.7 і опублікував розбір з реальними цифрами. Це найближче з усього знайденого до прямої відповіді на питання "скільки конкретно токенів їсть кожен рівень":

> *"Same $5/$25 pricing. Five effort tiers. 2.7x token cost between the cheapest and the most expensive."*

**Головні висновки автора (заголовок статті прямо каже "Max — це пастка"):**

- Розрив між найдешевшим (`low`) і найдорожчим (`max`) рівнем на тих самих 12 задачах — **2.7x за токенами**, узгоджується з іншим незалежним джерелом (Apiyi.com), яке фіксує ту саму цифру для порівняння max vs xhigh при маргінальному (~3 п.п.) прирості якості.
- Автор стверджує, що `low` "тихо вбив" якість Opus 4.6-подібного рівня — тобто на новому Opus `low` не еквівалентний старому дефолту, а суттєво слабший.
- `max` дає приріст, що рідко виправдовує подвоєну-потрійну вартість на звичайних задачах — узгоджується з офіційною порадою "step up to max only when your evals show measurable headroom".

**Застереження до цього джерела:** це один автор, 12 задач, стаття-думка (opinion piece), а не рецензований бенчмарк. Напрямок висновків повністю узгоджується з офіційною документацією й Apiyi.com, тому довіра середня, але конкретні числа ("2.7x", "3 п.п.") варто сприймати як орієнтир, не точну константу для будь-якого набору задач.

**Ще одна практична деталь з незалежного (Substack, Anthony Maio) технічного розбору Opus 4.7, яка прямо стосується твого сценарію (агенти, конфіги):**

Effort можна задавати шістьма способами з чітким порядком пріоритету:
1. `CLAUDE_CODE_EFFORT_LEVEL` env-змінна — б'є все інше
2. `--effort <рівень>` прапорець при запуску — діє на сесію
3. Effort у frontmatter скіла/саб-агента — перекриває дефолт, коли той скіл/саб-агент запущений
4. `/effort` команда в чаті

> *"If you set an effort level the active model doesn't support, Claude Code falls back to the highest supported level at or below it. xhigh on Opus 4.6 silently runs as high."*

**Практичний наслідок для mavitalk-agents:** якщо різні саб-агенти (планувальник, воркери) мають різні вимоги до effort — задавай його **в frontmatter конкретного скіла/саб-агента**, а не глобальною env-змінною, інакше глобальна змінна перекриє налаштування конкретного агента. І перевіряй, чи модель, яку викликає конкретний саб-агент, взагалі підтримує заданий рівень — тихий fallback на нижчий рівень без помилки означає, що поламане налаштування effort можна не помітити тижнями.

---

## 9. Мультиагентна оркестрація

Це прямо стосується твого планувальника тікетів. Знайшов кілька незалежних і офіційних джерел саме про паттерн "оркестратор + воркери".

### Офіційний паттерн Anthropic (Claude Code docs, code.claude.com)

Claude Code офіційно підтримує два різні механізми, і вибір між ними залежить від того, чи потрібна воркерам комунікація між собою:

> *"Use subagents when you need quick, focused workers that report back. Use agent teams when teammates need to share findings, challenge each other, and coordinate on their own."*

- **Subagents** — ієрархічна модель: один оркестратор → саб-агенти → звіт назад. Найбільш token-ефективний варіант, бо кожен саб-агент працює у власному чистому контексті.
- **Agent teams** (експериментально, вимкнено за замовчуванням) — паралельна модель через спільний task list, агенти координуються між собою напряму, без оркестратора-посередника. **Витрачає суттєво більше токенів** — офіційне застереження: *"Agent teams add coordination overhead and use significantly more tokens than a single session. They work best when teammates can operate independently. For sequential tasks, same-file edits, or work with many dependencies, a single session or subagents are more effective."*

**Для твого сценарію (планувальник розбиває тікети на підзадачі для черги воркерів-кодерів)** — це класичний **subagent-паттерн**, не agent teams: підзадачі відносно незалежні, воркерам не треба сперечатись між собою, звіт іде назад до оркестратора-планувальника.

### Практичне співвідношення моделей в оркестрації (кілька незалежних джерел сходяться)

| Джерело | Рекомендована пропорція/паттерн |
|---|---|
| CloudZero (cloudzero.com/blog/claude-code-agents) | *"Tier agents by model. Opus for the orchestrator. Sonnet for workers. Haiku for formatting. One team with tiered models costs ~40% less than all-Opus, with minimal capability loss on worker tasks."* |
| MindStudio (mindstudio.ai) | *"Setting up Opus as the orchestrator and Haiku or DeepSeek as sub-agents can reduce token costs by 5–10x without meaningful quality loss."* |
| AI for Anything (aiforanything.io) | *"Use Haiku for execution, Sonnet for reasoning — this alone cuts multi-agent costs by 60-80%"* |

> ⚠️ **Виправлення власної помилки:** у попередній версії цього розділу я написав, що "Sonnet-оркестратор економить 40-80% проти Opus-оркестратора" — це моя хибна екстраполяція. Насправді **жодне з трьох джерел у таблиці вище не порівнює Sonnet-оркестратор з Opus-оркестратором напряму**. Кожне джерело міряло своє: CloudZero — Opus+Sonnet+Haiku тіри проти all-Opus (40%); MindStudio — Opus-оркестратор з Haiku/DeepSeek-воркерами проти неуточненого базового варіанту (5-10x); AI for Anything — Haiku-виконання + Sonnet-reasoning проти неуточненого варіанту (60-80%). Змішувати ці цифри в одне число для іншого порівняння — некоректно.

**Чесний висновок:** усі три джерела сходяться в напрямку — *тіризація моделей за роллю (дорожча модель тільки для складного планування/reasoning, дешевша для виконання) суттєво знижує вартість без значної втрати якості*. Але конкретного, перевіреного числа "наскільки Sonnet-оркестратор дешевший за Opus-оркестратор" у знайдених джерелах немає. Якщо декомпозиція тікетів проста — тестуй Sonnet-оркестратор і виміряй економію на власних даних; якщо складна з заплутаними залежностями — Opus-оркестратор виправданий (за офіційною позицією розділу 1, а не за конкретним відсотком з community-джерел).

### Практичні застереження з реального використання (не лише вибір моделі)

- **Уникай циклічних залежностей між підзадачами** — якщо підзадача B потребує результату підзадачі A, вони не можуть виконуватись паралельно; проєктуй підзадачі як справді незалежні, або виконуй послідовно фазами.
- **Не передавай повний контекст кожному воркеру** — роздутий контекст витрачає токени й плутає спеціалізованого воркера; давай тільки те, що потрібно для конкретної підзадачі.
- **Валідуй вихід воркерів перед передачею далі** — LLM можуть повертати неочікувані формати; це особливо критично, якщо воркер передає результат наступному воркеру в ланцюжку.
- **Структуровані виводи економлять токени** — проси воркерів повертати JSON/таблиці замість прози.

---

## 10. Оновлена матриця

Матриця з попередньої версії файлу (розділ 5) залишається чинною. Додаю уточнення на основі Artificial Analysis і community-даних із розділів 7-9:

| Задача | Було (розділ 5) | Уточнення після розширеного дослідження |
|---|---|---|
| Складна декомпозиція тікетів з заплутаними залежностями | Sonnet 5 high → ескалація на Opus | **Підтверджено**: Opus-оркестратор виправданий саме тут, community-джерела (CloudZero, MindStudio) сходяться на цьому для складних координаційних рішень |
| Проста декомпозиція тікетів, чіткі незалежні підзадачі | Sonnet 5 high | **Уточнено (з виправленням):** community-джерела підтверджують напрямок "тіризація моделей за роллю економить суттєво", але конкретної цифри "Sonnet-оркестратор vs Opus-оркестратор" жодне джерело не дає напряму (див. виправлення в розділі 9) — тестуй на своїх задачах, не переплачуй за Opus без потреби, але й не покладайся на конкретний відсоток економії з цього файлу |
| Воркери-виконавці підзадач у черзі | Haiku 4.5 | **Підтверджено**: збігається з трьома незалежними джерелами про мультиагентну оркестрацію (розділ 9) |
| Найважчий кодинг/агентні задачі на Sonnet 5 xhigh/max | Xhigh для найважчих задач | **Уточнено з Artificial Analysis, з часовою поправкою**: на max effort і **стандартній ціні** ($3/$15, з 1 вересня 2026) Sonnet 5 коштує на 15% дорожче за Opus 4.8 за задачу. Але **до 31 серпня 2026 діє вступна ціна** ($2/$10) — за нею Sonnet 5 на max effort виходить приблизно на 23% **дешевшим** за Opus 4.8, не дорожчим. Перевіряй, яка ціна чинна на момент рішення, перш ніж вибирати модель через цей аргумент |
| Робота зі знаннями, документами, агентний аналіз даних | Не було виділено окремо | **Нове з Artificial Analysis**: тут Sonnet 5 реально випереджає Opus 4.8 на AA-Briefcase і GDPval-AA бенчмарках, незалежно від ціни — сюди Sonnet 5 честно кращий вибір, не просто дешевший |
| Effort-налаштування в продакшн-агентах | Explicit effort per задачу | **Посилено на основі community-ризику (8.3)**: Anthropic вже тихо змінювала дефолтний effort без анонсу, що ламало продуктивність продакшн-систем. **Обов'язково прописуй effort явно в конфігах/subagent YAML, ніколи не покладайся на дефолт для критичних агентів** |
| Прогноз бюджету на мультиагентні пайплайни | Не було | **Нове (8.4)**: adaptive thinking + паралельні саб-агенти без обмежень може спалити бюджет непропорційно швидко (задокументований кейс: $2500/місяць за 24 години). Став ліміти на паралелізм і/або max_tokens явно |

---

## 10.5. Звірка: де сторонні джерела реально доповнюють офіційну документацію, а де ні

Відповідь на пряме питання "чи справді дані зі сторонніх джерел ліпше застосувати, ніж офіційна документація":

### ✅ Випадки, де стороннє джерело дає щось, чого немає в офіційній документації (варто застосовувати як доповнення)

| Що | Офіційна документація каже | Стороннє джерело додає | Чому це не суперечність, а доповнення |
|---|---|---|---|
| Реальна вартість за задачу | Effort впливає на кількість токенів (якісно, без цифр) | Artificial Analysis: конкретні $/задача, кратність турнів | Anthropic не публікує end-to-end cost-per-task, тільки per-token ставки. Artificial Analysis вимірює те, чого офіційні docs не покривають в принципі |
| Ризик тихої зміни дефолтів | Не згадується (docs описують лише поточний стан) | Community: задокументований кейс зміни дефолтного effort без анонсу (лют-бер 2026) | Це історичний інцидент, офіційна документація за дизайном не документує власні минулі помилки |
| Патерн subagent vs agent teams — коли що використовувати | Технічний опис обох механізмів | Community: практичні приклади, коли який патерн підходить | Тут стороннє джерело не суперечить, а ілюструє офіційний матеріал прикладами |
| Реальний рефлекс розробників (не тюнити effort вручну) | Не описується (docs — нормативний документ, не етнографія використання) | HN-цитата | Корисно для дизайну дефолтів у ваших системах, не для суперечності з рекомендаціями |

### ⚠️ Випадки, де стороннє джерело УТОЧНЮЄ офіційну рекомендацію конкретною цифрою (застосовувати з обережністю, з датою)

| Що | Офіційна рекомендація | Уточнення Artificial Analysis | Статус після перевірки |
|---|---|---|---|
| "Xhigh для найважчих задач на Sonnet 5" | Просто "xhigh для найважчих задач" без цінового застереження | На max effort Sonnet 5 дорожчий за Opus 4.8 за задачу — **але тільки на стандартній ціні, що набуде чинності 1 вересня 2026** | Уточнення коректне, але я виправив часову прив'язку — до 31.08.2026 воно НЕ діє |

### ❌ Випадки, де я сам помилково видав інтерпретацію за факт джерела (виправлено в цій ревізії)

| Що | Що було написано | Що насправді кажуть джерела | Виправлення |
|---|---|---|---|
| "Sonnet-оркестратор економить 40-80% проти Opus-оркестратора" | Подано як підтверджена цифра з трьох джерел | Жодне з трьох джерел не порівнює саме ці два варіанти напряму — кожне міряло інше порівняння | Виправлено в розділах 9 і 10, тепер чесно позначено як відсутність прямих даних |
| "$2.29 доводить, що Sonnet 5 дорожчий за Opus" | Подано без часового застереження | Цифра стосується стандартної ціни, що ще не діє | Додано таблицю з перерахунком на вступну ціну |

### Загальний висновок по звірці

Жодне зі сторонніх джерел **не спростовує** офіційну документацію Anthropic — вони покривають різні речі. Офіційна документація каже **що робити** (рекомендовані effort-рівні, коли яку модель починати), сторонні джерела показують **скільки це реально коштує й наскільки надійно це працює на практиці**. Це доповнення, не заміна. Там, де в попередній ревізії файлу сторонні цифри подавались як остаточний факт без урахування контексту (часу дії ціни) або без перевірки, чи джерело справді виміряло те, що йому приписувалось — я це виправив вище.

**Практичне правило для команди:** якщо офіційна документація й стороннє джерело розходяться в конкретній рекомендації "що робити" — довіряй офіційній документації. Якщо стороннє джерело дає **цифру там, де офіційна документація мовчить** (вартість, надійність, історія змін) — використовуй її, але перевіряй дату й контекст, як показано в таблиці вище.

---

## 11. Статус доступності Fable 5 / Mythos 5

Перевірено на 1-2 липня 2026:

- **12.06.2026** — доступ призупинено через export control directive Держдепартаменту США (після знайденого дослідниками Amazon jailbreak, що дозволяв генерувати exploit-код).
- **30.06.2026** — обмеження зняті Держдепартаментом США.
- **01.07.2026** — Fable 5 відновлено **глобально** на Claude API, Claude Platform, Claude.ai, Claude Code, Claude Cowork.
- **Mythos 5** — відновлено тільки для ~100+ схвалених US-організацій через Project Glasswing (з 26.06.2026), не є загальнодоступним.

**Додаткова хронологія доступу через підписку (перевірено за незалежними джерелами, окрема від суспензії):** Fable 5 спочатку запущено 9 червня 2026; з 9 по 22 червня 2026 він був **безкоштовно** включений у Pro/Max/Team/seat-based Enterprise плани (Free-план — ні); з 23 червня 2026 доступ через підписку перейшов на usage credits за API-ставкою. Anthropic заявила намір повернути Fable 5 у flat-плани "коли дозволить потужність", без конкретної дати.

> ⚠️ **Операційне застереження, критичне для стандарту компанії (fallback tax):** Fable 5 має вбудовані safety-класифікатори на кібербезпеку й біологію/хімію. Коли запит їх тригерить, він **тихо перенаправляється на Opus 4.8 і білінгується за ставкою Opus 4.8** (не Fable). За оцінками джерел (finout.io, costlens.dev) це стосується ~5% сесій у середньому, але для команд, що працюють у security/bio/chem-суміжних доменах, реальна частка вища, бо класифікатор навмисно широкий. Практично: якщо твоє навантаження в цих доменах — закладай, що частина Fable 5-запитів фактично виконуватиметься Opus 4.8 (і за його ціною), а не тією моделлю, яку ти обрав. Refused-запит (до генерації виводу) коштує $0; перенаправлений — за ставкою Opus; перерваний посеред стріму — input плюс уже згенерований вивід.

⚠️ Це переважно джерела новинних медіа й трейд-аналітики (не офіційна технічна документація) — ситуація змінювалась кілька разів за 3 тижні. **Перевір актуальний статус перед плануванням**, якщо читаєш це значно пізніше 2 липня 2026.

---

## 12. Чек-лист вибору

Для розробника чи агента перед вибором моделі:

1. **Це складна агентна/enterprise робота** (multi-hour автономний агент, великий рефактор, складна системна інженерія)? → почни з **Opus 4.8**, effort `xhigh`.
2. **Це frontier-задача помірного масштабу** (генерація коду, аналіз даних, agentic tool use)? → почни з **Sonnet 5**, effort `high`.
3. **Це проста/масова/latency-sensitive задача** (класифікація, роутинг, sub-agent виконавець)? → почни з **Haiku 4.5**, thinking off.
4. **Задача підходить під офіційні критерії Fable 5** (раніше занадто складна/довга/неоднозначна навіть для Opus)? → **Fable 5**, effort `high`.
5. Перед підняттям effort **спробуй спочатку effort на поточній моделі**, а не заміну моделі — це офіційна рекомендація Anthropic ("tuning effort is often a better lever than switching models").
6. Якщо бачиш поверхневий reasoning на складній задачі при low/medium effort — **піднімай effort**, а не намагайся обійти це промптом.
7. Кібербезпекова робота (навіть санкціонована) → **Opus 4.8**, не Sonnet 5 (занижений cyber capability за дизайном) і не Fable 5 (блокуючі safety-класифікатори на offensive-техніки).
8. Завжди **вимірюй на власних evals**, перш ніж закріплювати вибір effort/моделі як стандарт — офіційна документація явно каже: "step down to medium or low only when you've measured that the lower level holds quality on your evals."
9. **Ніколи не покладайся на дефолтний effort у продакшн-агентах** — Anthropic вже тихо змінювала дефолти без анонсу, що ламало продуктивність існуючих систем (розділ 8.3). Прописуй effort явно в конфігах/subagent YAML.
10. Для мультиагентного планувальника: якщо підзадачі незалежні й не потребують комунікації між собою → **subagent-паттерн**, не agent teams (суттєво дешевше). Якщо задачі справді залежні між собою й потребують координації — тоді agent teams виправдані, попри вищу вартість.
11. Перед масштабуванням паралельних саб-агентів — **постав явний ліміт на кількість паралельних агентів і/або max_tokens** — задокументований ризик спалити місячний бюджет за добу (розділ 8.4).

---

## 13. Джерела

### Офіційна документація Anthropic (перевірено напряму 2 липня 2026, основне джерело істини цього файлу)

- `platform.claude.com/docs/en/about-claude/models/overview` — Models overview, таблиця порівняння моделей
- `platform.claude.com/docs/en/about-claude/models/choosing-a-model` — Choosing the right model, офіційна матриця вибору
- `platform.claude.com/docs/en/build-with-claude/effort` — Effort, повний опис параметра й рекомендацій по моделях
- `platform.claude.com/docs/en/build-with-claude/adaptive-thinking` — Adaptive thinking, технічні деталі
- `platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5` — специфічні поведінкові патерни Sonnet 5
- `platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8` — специфічні поведінкові патерни Opus 4.8
- `platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5` — специфічні поведінкові патерни Fable 5
- `platform.claude.com/docs/en/about-claude/models/whats-new-sonnet-5` — Sonnet 5 реліз-нотатки
- `platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8` — Opus 4.8 реліз-нотатки
- `platform.claude.com/docs/en/about-claude/pricing` — повна таблиця цін, включно з Batch API й prompt caching
- `platform.claude.com/docs/en/about-claude/use-case-guides/ticket-routing` — офіційний гайд по вибору моделі для ticket routing
- `code.claude.com/docs/en/agent-teams` — офіційна документація Claude Code про subagents vs agent teams

### Artificial Analysis (незалежна лабораторія, залучена самим Anthropic — розділ 7, висока довіра)

- artificialanalysis.ai/models/claude-opus-4-8 — Intelligence Index, вартість, швидкість Opus 4.8
- artificialanalysis.ai/models/claude-sonnet-5 — Intelligence Index, вартість, швидкість Sonnet 5
- artificialanalysis.ai/models/comparisons/claude-sonnet-5-vs-claude-opus-4-8 — пряме порівняння
- artificialanalysis.ai/articles/claude-sonnet-5-agentic-cost — детальний розбір вартості за задачу
- artificialanalysis.ai/articles/claude-opus-4-8-analysis-and-benchmarks — повний аналіз Opus 4.8
- x.com/ArtificialAnlys — офіційний акаунт з першоджерельними цифрами по релізах

### Community-джерела (розділ 8, середня/нижча довіра — конкретні цитати з прямим посиланням)

- news.ycombinator.com/item?id=48736605 — Hacker News тред запуску Sonnet 5 (155 балів, 63 коментарі)
- mayhemcode.com/2026/05/claude-opus-48-review — розслідування про тиху зміну дефолтного effort у лютому-березні 2026
- medium.com/@leucopsis/claude-opus-4-8-preliminary-review — токен-бьорн кейс, польові спостереження
- claudeai.dev/blog/claude-opus-4-8-feedback — агрегація Reddit-фідбеку по Opus 4.8
- cloudzero.com/blog/claude-code-agents — практичні пропорції моделей в оркестрації, FinOps-погляд
- mindstudio.ai/blog/smart-orchestrator-cheaper-sub-agent-models-claude-code — оркестратор/саб-агент паттерн
- aiforanything.io/blog/claude-multi-agent-orchestration-tutorial-2026 — orchestrator-subagent tutorial з конкретними цифрами економії
- pub.towardsai.net (Chew Loong Nian) — "I Tested All 5 Effort Levels of Claude Opus 4.7 on the Same 12 Coding Problems" — розділ 8.6, найближче до прямого вимірювання токенів по effort-рівнях
- anthonymaio.substack.com — "Opus 4.7: The Five Effort Levels in Claude Code Explained" — розділ 8.6, env var precedence, fallback-поведінка, практичні деталі конфігурації
- apiyi.com/blog (help.apiyi.com) — детальний розбір xhigh на Opus 4.7, tokenizer inflation, "reserve max for genuinely frontier problems"
- mindstudio.ai/blog/claude-code-effort-levels-explained — базове пояснення thinking budget по effort-рівнях
- mindstudio.ai/blog/claude-opus-4-8-effort-levels-explained — Ultra Code, декомпозиція по типах задач
- mindstudio.ai/blog/claude-sonnet-5-token-efficiency-cost — конкретний приклад розрахунку (10-крокова автоматизація, Opus vs Sonnet 5)
- findskill.ai/blog/claude-opus-4-8-effort-settings — claude.ai UI-номенклатура (Extra=xhigh), "sticky note" рекомендація
- verdent.ai/guides/claude-opus-4-7-vs-4-8 — міграційний гайд, ефект перекалібрування дефолту
- cloudzero.com/blog/claude-opus-4-8-pricing — Databricks 61% economy кейс, Fast Mode як cost lever
- claudefa.st/blog/models/claude-opus-4-8 — підтвердження зміни дефолту Claude Code (xhigh→high), якісна метрика "4x менше пропущених дефектів"
- vellum.ai/blog/claude-opus-4-8-benchmarks-explained — якісні метрики Opus 4.8, порівняння з GPT-5.5/Gemini
- finout.io/blog (два огляди: Opus 4.8 pricing, Fable 5/Mythos 5 pricing) — SWE-bench Pro для Fable 5, розрахунки Batch API арбітражу
- ayautomate.com/blog/claude-fable-5-pricing-explained — конкретні приклади вартості за завершену задачу для Fable 5
- developersdigest.tech/blog/claude-fable-5-pricing-cost-per-task-analysis — async-агент кейси Opus 4.8 vs Fable 5
- emergent.sh/learn/claude-fable-5-pricing — доступ через підписку, Batch API арбітраж
- digitalapplied.com/blog/claude-sonnet-5-opus-4-8-fable-5-when-to-use-which-2026 — "blended-effort average" уточнення до Artificial Analysis
- advisori.de/en/blog/claude-sonnet-5-benchmarks-pricing — деталізація токенізатора по типу контенту (код vs проза), community-фідбек r/ClaudeAI
- secondtalent.com/resources/claude-fable-vs-opus-vs-sonnet — практична евристика роутингу за складністю задачі

### Незалежні редакційні тести (розділ 6 попередньої версії, збережено для повноти)

- aireiter.com/blog/claude-sonnet-5-vs-opus-4-8
- coderabbit.ai/blog/claude-sonnet-5-review
- qodo.ai/blog (Qodo PR Benchmark)

### Новини про доступність Fable 5/Mythos 5 (розділ 11)

- coindesk.com, 9to5mac.com, venturebeat.com, thehackernews.com, cnbc.com (1–2 липня 2026)

---

### Обмеження та застереження

- Цей файл базується на документації, чинній на **2 липня 2026**. Anthropic регулярно оновлює effort-калібрування й рекомендації (наприклад, effort-рівні Opus 4.8 вже перекалібровані порівняно з 4.7) — **перевіряй офіційні docs перед великими рішеннями**, особливо якщо цей файл давно не оновлювався.
- Розділ 7 (Artificial Analysis) — найвища довіра серед незалежних джерел, бо сам Anthropic залучає цю лабораторію для передрелізного тестування, але це все одно не первинна документація Anthropic — цифри можуть уточнюватись при повторних вимірюваннях.
- Розділ 8 (community) відображає стан на дні після релізу Sonnet 5 і складається з поодиноких свідчень, а не систематичних досліджень — корисно для розуміння ризиків і патернів, але не для точних кількісних висновків. Цитати обрані як показові приклади з живих тредів, а не як репрезентативна вибірка думок спільноти.
- Розділ 9 (мультиагентна оркестрація) — рекомендації пропорцій моделей (напр. "40% дешевше", "5-10x") походять з окремих блог-джерел без спільної методології, тому це орієнтир напрямку, не точна цифра для вашого конкретного проєкту.
- Конкретні цифри вартості з попередньої версії файлу (наприклад, "$0.45 за задачу") — орієнтовні, з обмеженої вибірки тестів. Новий розділ 7 з Artificial Analysis дає більш надійну цифру ($2.29 за задачу для Sonnet 5 на max effort проти $1.99 для Opus 4.8), але навіть вона специфічна до методології Intelligence Index і може не відтворюватись на ваших реальних задачах. Завжди заміряй на власних задачах через `usage`-об'єкт API-відповіді.
- Пункт про Mythos 5/Fable 5 доступність (розділ 11) може змінитися — це найменш стабільна частина файлу.
- Цей файл покриває **десятки** проаналізованих джерел (офіційна документація Anthropic, Artificial Analysis, Hacker News, Reddit-агрегатори, кілька незалежних блогів про мультиагентну оркестрацію), але це все ще не вичерпний систематичний огляд усієї доступної інформації — трактуй як добре обґрунтовану відправну точку для стандарту компанії, яку варто переглядати з часом, а не як остаточну істину.
