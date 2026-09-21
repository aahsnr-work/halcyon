---
# Find where the following packages are installed in bazzite:

- [ ] uuidia

# Install the following packages from the following sources:

---

## Terra:

- [ ] zed
- [ ] zen-browser

---

# Move the following the packages to another module right after removal in a sys-devel.yml recipe

- [ ] nodejs
- [ ] npm

---

- [ ] brave-origin - place it with brave-browser

---

- [ ] All the following packages must be built in halcyon-packages repo even if available available in terra or fedora
  1. atuin
  2. bat
  3. bun
  4. cava
  5. chafa
  6. dust
  7. eza
  8. gnuplot
  9. pixi
  10. starship
  11. tealdeer
  12. uv
  13. yazi
  14. zellij

---

- [ ] No fonts should be installed using dnf or from terra repo. The container branch should mimic the fonts module from ublue-os/modules to install the following fonts:
  1. nerd-fonts:
     - JetBrainsMono
     - NerdFontsSymbolsOnly
  2. google-fonts:
     - JetBrains Mono
     - Noto Emoji
     - Noto Color Emoji

---

- [ ] For the following packages, get the PKGBUILDS and print them below along with their github/gitlab source, and the dnf spec files should be designed around them
  - com.ranfdev.DistroShelf
  - org.onlyoffice.desktopeditors
  - com.bitwarden.desktop
  - com.ticktick.TickTick
  - pyprland
  - obisidian
  - zotero

- [ ] Determine first where the bazzite image installs bazaar and baazite-portal from but keep in mind that these packages cab be installed from the terra repo

- [ ] I don't need the ryzenadj package

- [ ] texlive rpm packages like texlive-small, texlive-medium, texlive-full and other texlive groups, as well as how to install individual texlive packages like how dnf can install 'tex(beamer.cls)' with command `sudo dnf install 'tex(beamer.cls)'`
