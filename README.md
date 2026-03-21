# LocalHours

LocalHours is a lightweight KDE Plasma time-tracker widget with a local Python daemon.  
All tracked data stays on your machine by default.

## Installation (KDE Plasma 6)

Run:

```bash
./install.sh
```

The installer prefers distro Python packages and avoids changing system Python packaging policy by default.

### Python dependency fallback

Preferred packages:

- Arch/CachyOS/Manjaro: `sudo pacman -S python-pydbus python-gobject`
- Debian/Ubuntu: `sudo apt install python3-pydbus python3-gi`

If your distro packages are unavailable and you intentionally want the old behavior, opt in explicitly:

```bash
LOCALHOURS_ALLOW_BREAK_SYSTEM_PACKAGES=1 ./install.sh
```

## License

This project is licensed under the MIT License.  
See [LICENSE](LICENSE) for the full text.
