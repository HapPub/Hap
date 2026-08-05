<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-HapCLI-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie HapCLI" />
  <img src="https://img.shields.io/badge/version-0.1.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Version 0.1.0" />
  <img src="https://img.shields.io/badge/mode-local--first-2f855a?style=for-the-badge&labelColor=1f2430" alt="Локальная работа прежде всего" />
  <img src="https://img.shields.io/badge/focus-toolchain%20glue-805ad5?style=for-the-badge&labelColor=1f2430" alt="Слой совместимости инструментов" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">HapCLI</span><br/>
<span style="font-weight:100;font-size:24px">Локальный слой совместимости и восстановления инструментов</span>
<p align="center">
  <strong>Сначала проверка, затем план исправления, фиксированные адаптеры и проверяемый отчет.</strong><br/>
  <sub>Cangjie · cjpm · stdx · HarmonyOS · Kotlin Multiplatform · CI</sub>
</p>
</div>

[English](README.md) | [简体中文](README.zh-CN.md) | **Русский**

## Что такое HapCLI

HapCLI — это открытый слой совместимости командной строки для проектов, в которых настройки инструментов различаются между компьютером разработчика, CI, облачным сервером и подключенным устройством. Сейчас основное внимание уделяется Cangjie/cjpm, разработке приложений HarmonyOS и процессам Kotlin Multiplatform.

HapCLI не заменяет `cjpm`, Gradle, Xcode, DevEco Studio, `hdc` или менеджер пакетов. Он определяет фактическое состояние проекта и среды, создает проверяемый план, запускает ограниченный набор фиксированных адаптеров и сохраняет структурированный результат.

## Быстрый старт

На странице релиза доступны проверенные бинарные файлы для Linux AMD64,
Linux ARM64 и macOS ARM64. Сначала загрузите Hapup и манифест, созданный из
реальных артефактов, проверьте оба файла и установите бинарный файл для хоста:

```bash
VERSION=0.1.0
BASE="https://github.com/HapPub/Hap/releases/download/v$VERSION"
WORK="$(mktemp -d)"
cd "$WORK"
curl -fsSLO "$BASE/hapup.sh" -O "$BASE/hapup.sh.sha256"
curl -fsSLO "$BASE/manifest.v0.json" -O "$BASE/manifest.v0.json.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c hapup.sh.sha256
  sha256sum -c manifest.v0.json.sha256
else
  shasum -a 256 -c hapup.sh.sha256
  shasum -a 256 -c manifest.v0.json.sha256
fi
sh ./hapup.sh install-from-manifest \
  --manifest ./manifest.v0.json \
  --install-dir "$HOME/.local/bin" \
  --review-token reviewed
"$HOME/.local/bin/hap" version
```

Архив исходного кода всегда остается переносным резервным вариантом. Для
сборки нужны Cangjie SDK и `cjpm` 1.1.x. На macOS сначала укажите активный SDK:

```bash
export SDKROOT="$(xcrun --show-sdk-path)"
```

Соберите и установите команду в каталог пользователя:

```bash
cjpm build
mkdir -p "$HOME/.local/bin"
cp ./target/release/bin/main "$HOME/.local/bin/hap"
chmod +x "$HOME/.local/bin/hap"
hap version
```

Запустите первые проверки только для чтения в каталоге проекта:

```bash
hap project detect --project .
hap toolchain providers
hap help
```

Файл [`release/manifest.v0.json`](release/manifest.v0.json) в репозитории
описывает preview исходного кода. Каждый GitHub Release получает новый
манифест только из нативных заданий, прошедших сборку, тесты, checksum и
проверку `hap version`.

## Основные возможности

- Определение проектов Cangjie/cjpm, HarmonyOS, iOS и Compose Multiplatform.
- Проверка `cjpm.toml` и диагностика расхождений между локальными зависимостями `path` и удаленными зависимостями `git`.
- Запись рабочего профиля stdx и планирование либо применение исправления с резервной копией в другом проекте.
- Запуск фиксированных действий `cjpm build` и `cjpm bundle` с ограниченной диагностикой среды, одной проверяемой попыткой исправления и подсказкой о порядке публикации зависимостей в центральном репозитории.
- Сборка, установка, запуск и проверка приложений HarmonyOS через фиксированные команды `hvigor` и `hdc`.
- Хранение подтвержденных псевдонимов устройств HarmonyOS и последних беспроводных адресов, доказанных через USB, без сканирования локальной сети.
- Запуск настольных приложений Compose Multiplatform и сборка, установка и запуск iOS-приложений при наличии действующих средств подписи Apple на хосте.
- Диагностика GitHub Actions и создание проверяемых CI-сценариев без изменения workflow-файлов самим CLI.
- Краткий вывод по умолчанию; `-v` или `--verbose` включает структурированные подробности, а `--write-receipt` создает явный отчет для агента или CI.

## Типовые сценарии

### Cangjie и stdx

```bash
hap inspect-cjpm ./cjpm.toml
hap record cangjie.stdx --project . --target x86_64-unknown-linux-gnu
hap doctorfix cangjie.stdx --project . --target x86_64-unknown-linux-gnu --plan
hap build --project . --target x86_64-unknown-linux-gnu
hap bundle --project . --skip-lint
hap get cangjie-sdk --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/runtimes"
hap get cangjie-stdx --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/stdx"
```

Обе команды `get` только формируют план и не выполняют загрузку или установку.
Для `global` сначала используется побайтовое зеркало
[CangjieSDK-Mirror](https://github.com/HapPub/CangjieSDK-Mirror), а для `zh-cn`
сначала используется исходный release GitCode. В обоих встроенных маршрутах
источником SHA-256 служит `manifest.v1.json` зеркала. Явный
`--provider-url` остается пользовательским и не получает скрытого fallback.

### Разработка приложений HarmonyOS

```bash
hap project detect --project .
hap device --project .
hap dev --project .
hap dev --project . --device demo-phone
hap dev --project . --device 192.0.2.40:5555 -v
```

Если в каталоге найден только один поддерживаемый тип проекта, `hap dev` выбирает процесс автоматически. Параметр `--platform` нужен только для смешанных или неоднозначных каталогов.

### Kotlin Multiplatform

```bash
hap dev --project . --target desktop
hap dev --project . --target ios
hap dev --project . --target ios --useOld --artifact ./iosApp/build/Debug-iphoneos/DemoApp.app
```

### CI и граф зависимостей

```bash
hap ci action-doctor --workflow .github/workflows/build.yml --project . --target linux-amd64
hap cjpm graph doctor --manifest ./cjpm.toml
hap cjpm graph ci-workflow-export --manifest ./cjpm.toml --workflow-output /tmp/hap-preflight.yml --review-token reviewed
```

## Состояние платформ

| Область | Состояние | Честное ограничение |
| --- | --- | --- |
| Cangjie/cjpm на macOS arm64 | Проверены исходный код, тесты и выпуск по тегу | Статические объекты среды выполнения Cangjie 1.1.3 требуют macOS 13.3, даже если минимальная версия линковки указана ниже. |
| Cangjie/cjpm на Linux AMD64/ARM64 | Доступен выпуск по тегу | Каждый релиз требует сборки, тестов и проверки бинарного файла на нативном runner. |
| Windows AMD64 и macOS Intel | Проверены нативные nightly-сборки | Стабильный `v0.1.0` не меняется; nightly-бинарные файлы проходят сборку, тесты, упаковку и `hap version` на подходящих hosted runner. |
| OHOS ARM64/AMD64 | Доступна nightly cross-сборка с проверкой линковки | Артефакты не запускались на устройстве OHOS и требуют совместимой целевой среды выполнения Cangjie. |
| Windows ARM64/x86 | Зафиксирован пробел upstream | В зеркальном выпуске Cangjie нет подходящего нативного host SDK; другая архитектура не выдается за поддержку. |
| Приложения HarmonyOS | Доступен реальный процесс сборки, установки и запуска | Нужны рабочие инструменты DevEco, авторизованное устройство и действующий профиль подписи. |
| KMP Desktop на macOS | Проверен реальный запуск через Gradle | Другие настольные хосты требуют отдельной проверки. |
| KMP iOS/iPadOS | Реализованы сборка, установка и запуск | Учетная запись Apple, сертификат, профиль, команда разработки, сопряженное устройство и готовность CoreDevice остаются требованиями хоста. |
| Список Android-устройств | Доступно определение ADB только для чтения | Автоматизация сборки и установки APK пока не реализована. |

Отдельный nightly workflow собирает Linux AMD64/ARM64, macOS ARM64/Intel и
Windows AMD64 на соответствующих GitHub-hosted runner. Кроме того, OHOS
ARM64/AMD64 cross-собираются и проверяются на этапе линковки с Linux-to-OHOS
SDK Cangjie и проверенным по контрольной сумме sysroot OpenHarmony. Нативные
артефакты получают статус `sdk-independent-runtime-smoke-verified` только после
запуска `hap version` из распакованного архива без унаследованного окружения
SDK; cross-артефакты получают `cross-built-link-verified`. Каждый nightly также
публикует машиночитаемые отчеты о переносимости runtime и обо всех зеркальных
SDK, stdx, frontend, документации и исходных архивах, включая явное
доказательство отсутствия host SDK для Windows ARM64/x86.

## Настройка и безопасность

HapCLI читает приватную конфигурацию в следующем порядке:

1. `~/.hap/config.toml`
2. `./.hapData/config.toml` внутри проекта
3. `./happub.toml` внутри проекта, только после определения поддерживаемого типа проекта

Маршрут загрузки Cangjie выбирается в порядке `--region`, `HAP_REGION`, ключ
`downloadRegion` в TOML, сигналы locale/timezone и затем `global`. Допустимые
значения: `auto`, `global` и `zh-cn`:

```toml
downloadRegion = "auto"
```

Псевдонимы устройств используют ту же локальную схему резервных путей. В публичных примерах применяются только синтетические идентификаторы. Не добавляйте в репозиторий реальные серийные номера, UDID, адреса локальной сети, токены, отчеты или файлы памяти устройств.

Дочерние процессы по умолчанию запускаются в режиме `no-proxy`. Передайте `--proxy`, только если процесс должен наследовать переменные прокси текущей оболочки. Review token — это признак ручного подтверждения, а не средство аутентификации. Проверяемые поверхности выполнения не принимают произвольные shell-команды.

## Разработка и проверка

```bash
export SDKROOT="$(xcrun --show-sdk-path)"  # только macOS
cjpm build
cjpm test --timeout-each=30s --no-progress --no-color
sh -n release/hapup.sh
sh tests/hapup-security.sh
sh tests/public-surface.sh
sh tests/release-workflow.sh
sh tests/nightly-workflow.sh
```

Публичный workflow GitHub проверяет документацию, метаданные релиза, синтаксис shell, контрольные суммы и сценарии безопасности установщика. Тег `v*`, совпадающий с версией пакета, загружает официальный Cangjie SDK с закрепленной checksum; публикуются только бинарные файлы, прошедшие нативную сборку, тесты и проверку версии.

## Документация

- [Справочник команд](docs/COMMAND_REFERENCE.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Самообучение stdx и doctorfix](docs/STDX_SELF_LEARNING_AND_DOCTORFIX.md)
- [Граница выполнения stdx/runtime](docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md)
- [Политика подключения downstream-проектов](docs/DOWNSTREAM_ADOPTION_POLICY.md)
- [Процесс выпуска](docs/RELEASING.md)
- [Граница shell-компонента и основного CLI](docs/SHELL_AND_FLAGSHIP_BOUNDARY_2026-06-07.md)

## Границы проекта

HapCLI не является официальным инструментом Cangjie или HarmonyOS, не заменяет менеджер пакетов, не предоставляет реестр пакетов, не управляет версиями SDK и не переписывает манифесты незаметно. Доступность сторонних зеркал и инструментов устройств зависит от внешней среды.

Полный CLI и исходный код открыты по лицензии Apache License 2.0. Коммерческая поддержка может включать интеграцию, миграцию, обучение, помощь с развертыванием и обязательства по уровню сервиса, но не открывает скрытую закрытую редакцию CLI.

## Участие и безопасность

Перед отправкой изменений прочитайте [CONTRIBUTING.md](CONTRIBUTING.md). Сообщайте об уязвимостях приватным способом, описанным в [SECURITY.md](SECURITY.md), а не через публичный issue.

## Лицензия

HapCLI распространяется по [Apache License 2.0](LICENSE). Сведения об авторстве проекта находятся в [NOTICE](NOTICE).
