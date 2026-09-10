<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-HapCLI-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie HapCLI" />
  <img src="https://img.shields.io/badge/source-0.3.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Source 0.3.0" />
  <img src="https://img.shields.io/badge/mode-local--first-2f855a?style=for-the-badge&labelColor=1f2430" alt="Локальная работа прежде всего" />
  <img src="https://img.shields.io/badge/focus-toolchain%20glue-805ad5?style=for-the-badge&labelColor=1f2430" alt="Слой совместимости инструментов" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">HapCLI</span><br/>
<span style="font-weight:100;font-size:24px">Локальный слой совместимости и восстановления инструментов</span>
<p align="center">
  <strong>Сначала проверка, затем план исправления, фиксированные адаптеры и проверяемый отчет.</strong><br/>
  <sub>Cangjie · Semeru JDK · Android SDK · OpenHarmony · HarmonyOS · KMP</sub>
</p>
</div>

[English](README.md) | [简体中文](README.zh-CN.md) | **Русский**

## Что такое HapCLI

HapCLI — это открытый слой совместимости командной строки для проектов, в которых настройки инструментов различаются между компьютером разработчика, CI, облачным сервером и подключенным устройством. Он устанавливает Cangjie и инструменты SDK/JDK, поддерживает Cangjie/cjpm, разработку приложений HarmonyOS и процессы Kotlin Multiplatform.

HapCLI не заменяет `cjpm`, Gradle, Xcode, DevEco Studio, `hdc` или менеджер пакетов. Он определяет фактическое состояние проекта и среды, создает проверяемый план, запускает ограниченный набор фиксированных адаптеров и сохраняет структурированный результат.

## Быстрый старт

Это руководство описывает **исходный код версии 0.3.0**. Доступные версии и
бинарные файлы перечислены в [GitHub Releases](https://github.com/HapPub/Hap/releases).
Версия исходного кода не означает, что соответствующий бинарный релиз уже опубликован.

Если установлен Hapup 0.2.0 или новее, установите последний опубликованный HapCLI:

```bash
hapup install
hap version
```

Для первой установки см. [руководство](docs/INSTALLATION.md).
Если опубликованный бинарный файл ещё не поддерживает нужные команды,
[соберите текущие исходники](docs/INSTALLATION.md#build-from-source).
Полная установка Cangjie требует HapCLI 0.2.0 или новее; установка SDK/JDK —
**0.3.0 или новее**.

Компилятор сборки выбирается отдельно: см. [выпуски с Cangjie 1.0.5 / 1.1.3](docs/RELEASING.md#selecting-a-toolchain-qualified-release). При ручной установке сохраняйте библиотеки из архива.

### Установка инструментов

```bash
hap get cangjie --version sts
# Точная версия: hap get cangjie --version 1.1.3
hap get jdk --provider semeru --version 17
hap get android --version 36 --accept-licenses
hap get ohos --version 6.0 --profile native
```

Для Cangjie `sts` автоматически выбирает SDK **1.1.3** и stdx **1.1.3.1**,
опубликованные под разными тегами. Установщики загружают и проверяют пакеты,
проверяют инструменты и только затем активируют приватную среду.
Новые терминалы загружают её автоматически; в текущем выполните команду из
`activationHint`. `--plan` не обращается к сети и не записывает файлы;
`--no-activate` устанавливает файлы без переключения активной среды.

Установка SDK/JDK выполняется на **нативном хосте macOS/Linux**; для Windows и
других целевых хостов доступен только план. Каталоги различаются: встроенный
каталог HarmonyOS сейчас предназначен для **Linux x64**:

```bash
hap get harmonyos --version 5.1.0.840 --accept-licenses
```

Для других хостов или версий HarmonyOS нужен официальный архив либо HTTPS URL
и SHA-256. Перед `--accept-licenses` прочитайте условия поставщика.
Android NDK/CMake, поддерживаемые платформы, отдельная Java для SDK и совместная
настройка сред описаны в [руководстве SDK/JDK](docs/SDK_TOOLCHAINS.md).

### Проверка проекта

```bash
hap project detect --project .
hap toolchain providers
hap help
```

## Основные возможности

- Раздельное определение обычных проектов Cangjie/cjpm, нативных пакетных рабочих пространств HarmonyOS на Cangjie, проектов HarmonyOS на hvigor, iOS и Compose Multiplatform.
- Проверка таблиц `[app]` / `[workspace]` и графа модулей HAP/HSP/HAR до выбора поставщика упаковки.
- Проверка `cjpm.toml` и диагностика расхождений между локальными зависимостями `path` и удаленными зависимостями `git`.
- Запись рабочего профиля stdx и планирование либо применение исправления с резервной копией в другом проекте.
- Запуск фиксированных действий `cjpm build` и `cjpm bundle` с ограниченной диагностикой среды, одной проверяемой попыткой исправления и подсказкой о порядке публикации зависимостей в центральном репозитории.
- Сборка, установка, запуск и проверка приложений HarmonyOS через фиксированные команды `hvigor` и `hdc`.
- Запрос размера окна HarmonyOS для профилей Phone/Tablet/Fold/PC, привязка
  фактического прямоугольника WMS к PID пакета и создание структурированной
  квитанции снимка окна.
- Хранение подтвержденных псевдонимов устройств HarmonyOS и последних беспроводных адресов, доказанных через USB, без сканирования локальной сети.
- Запуск настольных приложений Compose Multiplatform и сборка, установка и запуск iOS-приложений при наличии действующих средств подписи Apple на хосте.
- Диагностика GitHub Actions и создание проверяемых CI-сценариев без изменения workflow-файлов самим CLI.
- `hap get cangjie` устанавливает полную пару SDK/stdx, проверяет компиляцию и запуск, затем настраивает shell с резервной копией; компонентный `hap install cangjie*` не меняет настройки shell.
- Установка Semeru JDK, Android SDK с дополнительными NDK/CMake, OpenHarmony SDK и HarmonyOS Command Line Tools с проверкой пакетов и инструментов и раздельным управлением средами. Доступность зависит от поставщика и хоста.
- Краткий вывод по умолчанию; `-v` или `--verbose` включает структурированные подробности, а `--write-receipt` создает явный отчет для агента или CI.

## Типовые сценарии

### Cangjie и stdx

```bash
hap inspect-cjpm ./cjpm.toml
hap record cangjie.stdx --project . --target x86_64-unknown-linux-gnu
hap doctorfix cangjie.stdx --project . --target x86_64-unknown-linux-gnu --plan
hap build --project . --target x86_64-unknown-linux-gnu
hap bundle --project . --skip-lint
hap install cangjie@latest --target macos-arm64 --region auto
hap install cangjie-sdk@1.1.3 --target linux-amd64 --region global
hap install cangjie-stdx@1.1.3 --target macos-arm64 --region zh-cn
hap install cangjie@nightly --target macos-arm64 --route auto
hap install cangjie@latest --target macos-arm64 --plan
hap get cangjie-sdk --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/runtimes"
hap get cangjie-stdx --target linux-amd64 --version <nightly-tag> --region auto --install-root "$HOME/.hap/stdx"
```

В компонентном интерфейсе `hap install` `cangjie` — псевдоним `cangjie-sdk`; `cangjie-stdx` остается отдельным пакетом.
Версия по умолчанию, `@latest` и `@lts` фиксируются на LTS `1.0.5`, а
`@1.1.3` остается точной STS-линией. `@nightly` динамически выбирает новейший
проверенный prerelease; точный ограниченный nightly-тег, например
`@1.3.0-alpha.20260828010050`, остаётся воспроизводимым. Установка идет в
`~/.hap/toolchains`;
явный корень допускается только внутри `HOME/.hap` или временного каталога ОС.
`--plan` не загружает и не изменяет файлы.

Точная команда `hap install cangjie` в интерактивном терминале открывает TUI:
пользователь выбирает LTS, STS или текущий динамически найденный nightly, видит
ограниченное по времени HTTPS-измерение
зеркала, разрешённых ускорителей и официального источника, затем выбирает
автоматически самый быстрый успешный маршрут либо один принудительный маршрут.
Скрипты, перенаправленный ввод, явные версии и `--plan` остаются
неинтерактивными. Для скриптов и CI доступен
`--route auto|mirror|ghfast|ghproxy|official`; принудительный маршрут не имеет
скрытого fallback. Задержка является только транспортным наблюдением и не
заменяет закреплённый SHA-256.

Старые команды `get` остаются только планами получения. Реальная установка
nightly теперь доступна через `install`; `--plan` сообщает об ожидающем
динамическом разрешении без сетевого запроса. HapCLI использует
`https://cli.hap.pub/manifests/cangjie-install-v1.json` как дополнительный
словарь со строгой проверкой schema и при его отсутствии, устаревании или HTML
fallback обращается к живому индексу HapPub Mirror. Точный `manifest.v1.json`
выбранного выпуска остаётся источником списка файлов и SHA-256. Для стабильной установки
`global` сначала использует побайтовое зеркало
[CangjieSDK-Mirror](https://github.com/HapPub/CangjieSDK-Mirror), а `zh-cn`
добавляет разрешенные ускоряющие префиксы к тому же URL, затем использует
прямое зеркало и официальный источник. Ускоритель не является источником
контрольной суммы.

### Разработка приложений HarmonyOS

```bash
hap project detect --project .
hap device --project .
hap dev --project .
hap dev --project . --device demo-phone
hap dev --project . --device 192.0.2.40:5555 -v
hap prnt --project . --device demo-pc --layoutType Phone --ratio 18:9 --plan
hap prnt --project . --device demo-pc --layoutType Tablet/Fold4:3
```

Чистое рабочее пространство HarmonyOS на Cangjie определяется как отдельный
тип `cangjie-harmonyos`, а не как обычный `cangjie` или проект hvigor:

```bash
hap project detect --project ./native-harmony-app
hap build --project ./native-harmony-app --platform cangjie-harmonyos --plan
```

Детектор читает `[app]` / `[workspace]` корневого манифеста и `[hap]`, `[hsp]`,
`[har]` модулей. Упаковка закрыта по умолчанию: план возвращает
`package-provider-required`, пока не подключен отдельно проверенный поставщик с
фиксированными argv и структурированными квитанциями. Этот режим не создает,
не подписывает, не устанавливает и не запускает HAP.

`hap prnt` сначала задает геометрию окна, затем проверяет PID и фактический
прямоугольник WMS, снимает весь дисплей и обрезает его по данным WMS. Профили:
Phone — `16:9`, `18:9`, `21:9`; Tablet/Fold — `Fold4:3`, `Fold√2:1`,
`Fold1.15:1`, `16:9`, `3:2`, `7:5`; PC — `2in1`. Значение `trible`
принимается только вместе с `--width` и `--height`, без выдуманного соотношения.
Внешний снимок может содержать перекрывающие окна и не заменяет визуальную приемку.

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
| Установка SDK/JDK | Выполнение на нативном macOS/Linux; Windows и другие хосты — только план | Доступность пакетов ниже не равна доступности бинарных файлов HapCLI. |
| IBM Semeru JDK | Установка из GitHub Releases; компиляция/запуск Java проверены на macOS ARM64 | Нужен подходящий архив Open Edition JDK; совместимость со всеми проектами Gradle не гарантируется. |
| Android SDK/NDK/CMake | Каталог macOS Intel/ARM и Linux x64; контролируемые интеграционные проверки пройдены | Проверка реальной загрузки у поставщика ещё не завершена; нужны принятие условий и совместимая Java. |
| OpenHarmony SDK | Каталог 6.0 для macOS Intel/ARM и Linux x64; native/full проверены на macOS ARM64 | SDK 6.0.0.47 / API 20; компиляция целевого объектного файла не доказывает запуск на устройстве. |
| HarmonyOS Command Line Tools | Встроенный каталог Linux x64 5.1.0.840; официальный архив или URL | Проверка текущего пакета macOS ещё не завершена; для других хостов/версий нужны официальные файлы и SHA-256. |
| Cangjie/cjpm на macOS arm64 | Проверены исходный код, тесты и выпуск по тегу | Статические объекты среды выполнения Cangjie 1.1.3 требуют macOS 13.3, даже если минимальная версия линковки указана ниже. |
| Cangjie/cjpm на Linux AMD64/ARM64 | Доступен выпуск по тегу | Каждый релиз требует сборки, тестов и проверки бинарного файла на нативном runner. |
| Windows AMD64 | Включён в обе сборки с фиксированным компилятором | Нужны нативные тесты и запуск из ZIP; установка SDK остаётся только планом. |
| macOS Intel | Нативная сборка nightly | В стабильных каталогах 1.0.5/1.1.3 нет SDK для этого хоста; нужен соответствующий nightly SDK. |
| OHOS ARM64/AMD64 | Доступна nightly cross-сборка с проверкой линковки | Артефакты не запускались на устройстве OHOS и требуют совместимой целевой среды выполнения Cangjie. |
| Windows ARM64/x86 | Зафиксирован пробел upstream | В зеркальном выпуске Cangjie нет подходящего нативного host SDK; другая архитектура не выдается за поддержку. |
| Приложения HarmonyOS | Доступен реальный процесс сборки, установки и запуска | Нужны рабочие инструменты DevEco, авторизованное устройство и действующий профиль подписи. |
| Нативные пакеты HarmonyOS на Cangjie | Доступны определение, граф HAP/HSP/HAR и план поставщика | Создание пакетов закрыто до интеграции проверенного фиксированного поставщика. |
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

Для проектов Cangjie флагманская команда `hap build --target ohos` по
умолчанию включает bootstrap toolchain. Если отсутствует `cjpm` или целевой
stdx, Hap выбирает точную пару SDK/stdx из manifest зеркала, проверяет
загруженные архивы по SHA-256, устанавливает их в приватный кеш и передает
окружение только фиксированному дочернему процессу сборки:

```toml
toolchainAutoBootstrap = true
cangjieSdkVersion = "auto"
toolchainCacheRoot = "/absolute/path/to/hap-toolchains"
toolchainBootstrapTimeoutSeconds = 900
toolchainDownloadRetryCount = 2
downloadAcceleration = "auto"
downloadAccelerators = ["https://ghfast.top/", "https://ghproxy.link/"]
```

Отключение выполняется через `--no-toolchain-bootstrap`. Bootstrap SDK/stdx
не устанавливает и не подтверждает native sysroot OpenHarmony, подпись,
runtime или приемку на устройстве.

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

- [Установка HapCLI и Cangjie](docs/INSTALLATION.md)
- [Установка SDK и JDK](docs/SDK_TOOLCHAINS.md)
- [Справочник команд](docs/COMMAND_REFERENCE.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Самообучение stdx и doctorfix](docs/STDX_SELF_LEARNING_AND_DOCTORFIX.md)
- [Граница выполнения stdx/runtime](docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md)
- [Политика подключения downstream-проектов](docs/DOWNSTREAM_ADOPTION_POLICY.md)
- [Процесс выпуска](docs/RELEASING.md)
- [Граница shell-компонента и основного CLI](docs/SHELL_AND_FLAGSHIP_BOUNDARY_2026-06-07.md)

## Границы проекта

HapCLI не является официальным инструментом Cangjie или HarmonyOS, не заменяет менеджер пакетов, не предоставляет реестр пакетов, не является универсальным менеджером SDK и не переписывает манифесты незаметно. Доступность сторонних зеркал и инструментов устройств зависит от внешней среды.

Полный CLI и исходный код открыты по лицензии Apache License 2.0. Коммерческая поддержка может включать интеграцию, миграцию, обучение, помощь с развертыванием и обязательства по уровню сервиса, но не открывает скрытую закрытую редакцию CLI.

## Участие и безопасность

Перед отправкой изменений прочитайте [CONTRIBUTING.md](CONTRIBUTING.md). Сообщайте об уязвимостях приватным способом, описанным в [SECURITY.md](SECURITY.md), а не через публичный issue.

## Лицензия

HapCLI распространяется по [Apache License 2.0](LICENSE). Сведения об авторстве проекта находятся в [NOTICE](NOTICE).
