# AyOS Material 26.11 — ayospacstrap/main.py
#
# Честная установка: pacstrap свежей базовой системы из репозиториев
# в примонтированный target. Выполняется на стороне live (pacstrap требует
# рабочий pacman; пустой target ещё нельзя chroot'нуть).
#
# Ядро linux ставится ПОЗЖЕ (ayos-edition / contextualprocess): к этому моменту
# уже готовы keyring + DNS, os-release цели = AyOS (заголовок boot-записи
# kernel-install берёт из os-release), initramfs собирается чистым конфигом
# (живых archiso-хуков в цели больше не заводится).

import os
import shutil
import subprocess


def run():
    root = libcalamares.globalstorage.value("rootMountPoint")
    if not root or not os.path.isdir(root):
        return ("[ayospacstrap] rootMountPoint is missing",
                "pacstrap needs a mounted root.",
                "Check the 'mount' module log above.")

    packages = list(libcalamares.job.configuration.get("packages", []))
    if not packages:
        return ("[ayospacstrap] no packages configured",
                "The 'packages' list in ayospacstrap.conf is empty.",
                "Fix calamares/modules/ayospacstrap/ayospacstrap.conf.")

    # Редакция (выбор на GUI-этапе уже в GlobalStorage): подмешиваем её
    # набор к pacstrap-транзакции. Так указанная большая загрузка
    # (plasma/gnome/...) идёт ПО видимой полосе, а не молча в shellprocess
    # (прогон #5: ayos-edition в target качал весь Plasma и был прибит
    # таймаутом 900 c). nvidia-*/linux всё равно ставятся в ayos-edition:
    # им нужен уже готовый AyOS os-release.
    edition_key = libcalamares.globalstorage.value("packagechooser_packagechooser")
    editions = libcalamares.job.configuration.get("editions", {})
    if isinstance(edition_key, str) and edition_key in editions:
        ed_pkgs = list(editions[edition_key])
        libcalamares.utils.debug(
            "ayospacstrap: edition '{}': +{} packages via pacstrap".format(
                edition_key, len(ed_pkgs)))
        packages = packages + ed_pkgs

    libcalamares.utils.debug("ayospacstrap: target = {}".format(root))

    # Все вызовы libcalamares обёрнуты в try/except: недоступность какого-то
    # API лишь отключает косметику (живую полосу), но не ломает установку.
    def _setprogress(f):
        try:
            libcalamares.job.progress(f)
        except Exception:
            pass

    # В live-среде keyring'а нет (squashfs собирается без /etc/pacman.d/gnupg).
    # А pacstrap гоняет pacman в host-энвайронменте, значит подписи проверяет
    # ИМЕННО live-keyring. Инициализируем офлайн (ключи уже на диске,
    # /usr/share/pacman/keyrings). Единожды, ~10–20 c, только при установке.
    if not os.path.isfile("/etc/pacman.d/gnupg/pubring.gpg"):
        libcalamares.utils.debug("ayospacstrap: init live pacman keyring")
        for argv in (["pacman-key", "--init"],
                     ["pacman-key", "--populate", "archlinux"]):
            r = subprocess.call(argv)
            if r != 0:
                return ("[ayospacstrap] pacman-key failed",
                        "{} exit code {}".format(" ".join(argv), r),
                        "See Calamares log.")

    # Полоса должна жить с первых секунд: до начала пакетов идут pacman-key
    # (~20-40 c) и синхронизация репо-дб через NAT (~1-2 мин) - это выглядит
    # как "тишина", её путали с зависанием (прогон #3).
    _setprogress(0.02)

    # Скорость: pacstrap берёт host-мирлист. Первый сервер там worldwide -
    # через slirp+NAT он может быть "медленным, но живым" (pacman не
    # переключается дальше, пока что-то работает). Ставим проверенно
    # быстрый сервер первым, остальной список остаётся фолбэком.
    MIRRORLIST = "/etc/pacman.d/mirrorlist"
    FAST = "Server = https://mirror.yandex.ru/archlinux/$repo/os/$arch\n"
    try:
        with open(MIRRORLIST) as f:
            ml = f.read()
        if FAST.strip() not in ml:
            libcalamares.utils.debug("ayospacstrap: prepend fast mirror")
            with open(MIRRORLIST, "w") as f:
                f.write(FAST + ml)
    except Exception as e:
        libcalamares.utils.debug(
            "ayospacstrap: mirrorlist tweak skipped: {}".format(e))

    # pacstrap сам копирует keyring host'а (мы его инициализировали),
    # mirrorlist, дефолтный pacman.conf из пакета и --noconfirm стоит
    # по умолчанию (проверено по /usr/bin/pacstrap arch-install-scripts).
    # Прогресс: строки pacstrap/pacman идут в лог Calamares
    # (tail -f /var/log/calamares.log) и двигают полосу установки.
    libcalamares.utils.debug("ayospacstrap: {} packages".format(len(packages)))

    proc = subprocess.Popen(["pacstrap", root] + packages,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT,
                            text=True, errors="replace", bufsize=1)
    installed = 0.0
    crawl = 0.02
    ESTIMATE = 600.0    # грубая оценка числа пакетов транзакции (с зависимостями)
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            libcalamares.utils.debug("[ayospacstrap] " + line)
        except Exception:
            pass
        if line.startswith("installing "):
            installed += 1.0
            _setprogress(0.10 + 0.85 * min(installed, ESTIMATE) / ESTIMATE)
        elif ("retrieving " in line.lower() or "downloading " in line.lower()
              or "receiving " in line.lower() or "synchronizing " in line.lower()
              or "checking keys" in line or "checking keyring" in line
              or line.startswith("==> ")):
            # Фаза подготовки (pacman-key, sync/db, checking): ползём мягко
            # вверх до 8%, чтобы полоса не стояла как вкопанная.
            crawl = min(0.08, crawl + 0.005)
            _setprogress(crawl)
    r = proc.wait()
    if r != 0:
        return ("[ayospacstrap] pacstrap failed",
                "pacstrap exit code {}".format(r),
                "Смотри /var/log/calamares.log: строки с тегом [ayospacstrap].")

    # sudo для wheel (users.conf: sudoersGroup: wheel). sudo в наборе,
    # но правило гарантируем явно - чистый target получает ванильные
    # (закомментированные) sudoers из пакета.
    sudoers_d = os.path.join(root, "etc", "sudoers.d")
    os.makedirs(sudoers_d, exist_ok=True)
    sudoers_file = os.path.join(sudoers_d, "10-ayos")
    with open(sudoers_file, "w") as f:
        f.write("%wheel ALL=(ALL:ALL) ALL\n")
    os.chmod(sudoers_file, 0o440)

    # Chroot-модули Calamares (shellprocess@ayos_osrelease и
    # contextualprocess -> ayos-edition, ayos_angelos) исполняют AyOS-хелперы
    # ВНУТРИ цели (у них dontChroot: false). pacstrap приносит только
    # репозиторные пакеты, поэтому доставляем хелперы в цель руками:
    # исходники - это работающий live-корень (мы в host-контексте).
    helpers_dir = os.path.join(root, "usr", "local", "bin")
    os.makedirs(helpers_dir, exist_ok=True)
    for name in ("ayos-osrelease", "ayos-edition", "ayos-angelos"):
        src = os.path.join("/usr/local/bin", name)
        if os.path.isfile(src):
            dst = os.path.join(helpers_dir, name)
            shutil.copy2(src, dst)
            os.chmod(dst, 0o755)
        else:
            libcalamares.utils.debug("ayospacstrap: live helper missing: {}".format(src))
    # Ассеты хелперов (логотип fastfetch и прочее фирменное).
    if os.path.isdir("/usr/share/ayos"):
        shutil.copytree("/usr/share/ayos",
                        os.path.join(root, "usr", "share", "ayos"),
                        dirs_exist_ok=True)

    # Обои и дефолтные конфиги под обои (KDE-скел/xfconf/dconf) и zram:
    # pacstrap приносит только пакетные файлы - наши airootfs-вложения
    # в target не попадают иначе, чем явной доставкой (см. ключи ниже).
    asset_paths = [
        "/usr/share/backgrounds/ayos",
        "/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc",
        "/etc/xdg/xfconf/xfce-perchannel-xml/xfce4-desktop.xml",
        "/etc/dconf/profile/user",
        "/etc/dconf/db/local.d/00-background",
        "/etc/systemd/zram-generator.conf",
    ]
    for src in asset_paths:
        if not os.path.exists(src):
            libcalamares.utils.debug("ayospacstrap: live asset missing: {}".format(src))
            continue
        dst = os.path.join(root, src.lstrip("/"))
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

    # Собственные «оптимизации» (в стиле CachyOS, но свои и без сборки
    # нового ядра):ParallelDownloads в pacman и MAKEFLAGS=-j$(nproc) в
    # makepkg - простые текстовые патчи конфигов target'а.
    try:
        pconf = os.path.join(root, "etc", "pacman.conf")
        with open(pconf) as f:
            content = f.read()
        if "ParallelDownloads" not in content:
            content = content.replace(
                "[options]\n",
                "[options]\n# AyOS: downloads in parallel (packet set is large)\nParallelDownloads = 10\n",
                1)
            with open(pconf, "w") as f:
                f.write(content)
    except Exception as e:
        libcalamares.utils.debug("ayospacstrap: pacman.conf opts skipped: {}".format(e))
    try:
        mconf = os.path.join(root, "etc", "makepkg.conf")
        with open(mconf) as f:
            content = f.read()
        if "#MAKEFLAGS" in content:
            content = content.replace(
                "#MAKEFLAGS=\"-j2\"",
                "MAKEFLAGS=\"-j$(nproc)\"",
                1)
            content = content.replace(
                "#MAKEFLAGS=-j2",
                "MAKEFLAGS=-j$(nproc)",
                1)
            with open(mconf, "w") as f:
                f.write(content)
    except Exception as e:
        libcalamares.utils.debug("ayospacstrap: makepkg.conf opts skipped: {}".format(e))

    return None
