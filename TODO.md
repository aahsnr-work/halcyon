# TODO

- [x] apps-verify.sh fails
- [x] desktop-verify.sh fails
- [x] all scripts need to be more verbose at every step to be useful in github workflows
- [x] integrate texlive niceties likely from archive repo in github
- [x] also get the brew setup from one my past projects where brew packages were immediately available after 1st login
- [ ] Make sure security best practices are used throughout the halcyon project
- [ ] verify that the python packages installed correctly.
- [ ] gets some just files from my previous projects
- [ ] Check that pyprland systemd service is running or not in the running system
- [ ] try to avoid install steam, lutris from flatpaks
- [ ] From the logs make sure all non-fedora repos are removed after package is installed from it. Also make sure that everything is correct and in order and that the github workflow performed without issues.
- [x] Carefully study the rakuos linux project and its various repositories and then, from the rakuos project, implement P03 kernel, native-gaming, nvidia integration with P03 kernel, plymouth theming with my own logo while always using the bluebuild system. Do not implement the Containerfile system from the rakuos repos. Also do not implement their rum package manager. And only explain to me in a nix.md file how the rakuos project sets up nix.
- [ ] Convert all flatpaks to manual installs, including mailsping
- [ ] Implement adguard home to halcyon and most abilities from opensense
- [ ] Implement hardened security for all the files in public repo and github workflow, as well as for the github repo.
- [ ] Harden the custom image like securefin linux as well
- [ ] Setup distroshelf as dnf spec and install from rpm
- [ ] Install bitwarden as rpm download from official repos.
- [ ] Install ticktick as rpm from official sources
- [x] chezmoi should be installed from the official fedora repo. Then the chezmoi setup in this branch should be exact same as the main branch (blue-build module semantics: --git condition, --no-tty --force update, OnBootSec=5m/OnUnitInactiveSec=1d timer, --global enablement)
- [x] organize the bash scripts in build_files used by Containerfile into logical folders since there are so many scripts.
- [x] Also implement the packages.json style from https://github.com/ublue-os/main so that it is easier to manage packages. Then the bash scripts in build files will just call from this json file. Ask me any questions you need.
- [ ] Look at all the ublue-os repos.
- [x] Integrate brew and install brew packages baked into the custom image. (build_files/brew + Brewfile payload + boot-time seeding unit + user fallback + update/upgrade timers)
- [ ] Make zsh the default shell for my os but just for the user.
- [ ] Transfer my image to fedora 45 as the base.
- [ ] Carefully study, audit and review all the files and folders in the container branch of the halcyon project. Search the web and think longer for this task. Then apply the fixes. Then perform an identical build process of the custom image like how github workflow builds the custom image.
- [ ] `Importasnt` _halcyon_ is too difficult to pronounce. Change it zielOS
- [ ] Take background from ublue-os/artwork github repo

- [ ] Create a proper README.md for my project using Opus
- [ ] Integrate pia vpn into the custom image

---

You must perform the following tasks carefully, but if you get stuck, retry the task 3-5 times at least before giving up:

1. Carefully study the whole repo of the container branch of halcyon. Then audit and review all the files and folders in it. Search the web and think longer for these tasks. Then apply these fixes and changes

2. Now for all the files and folders inside the .github folder, determine if the current files and folders that were placed should correclty be placed there. If these files and folders are correctly placed, then make sure there are no errors and issues in these files and folders. Furthermore determine if there are any missing files needed for the github workflows for this container branch. Determine if the correct workflows are properly set up. For these tasks related to files and folders inside .github, look at the following repositories:

- https://github.com/ublue-os/image-template
- https://github.com/ublue-os/main
- https://github.com/ublue-os/aurora
- https://github.com/ublue-os/bazzite
- https://github.com/ublue-os/bluefin

3. Next study the brew module from https://github.com/blue-build/modules and the brew setup integration from the main branch of https://github.com/aahsnr-work/halcyon; then study how the brew packages were baked into the custom image, in other words, during building of the custom image. Then integrate all these brew setup from these locations into the container branch as closely as possible but most importantly functional.

4. Make sure just is properly integrated in this custom image. Make sure ujust command works perfectly. Make sure there is no errors when executing `ujust --choose`

5. Also look at chezmoi module from ublue-os/modules and chezmoi setup from the main branch of halcyon. Make sure both these setups are perfectly mimicked in the container branch. Currently chezmoi is installed using dnf. But if the mimic of the perfect setup in the container branch causes problem with the dnf install chezmoi, then chezmoi must be installed the way chezmoi module is installed using ublue-os/modules and ublue-so's homebrew trap

6. There must be verification bash scripts for all these tasks in this list.

7. Furthermore, all the bash scripts in the container branch must be verbose and distinct so that it is easier to detect error during the build while scrolling through the build. The verbosity and distinction could be applicable to the Containerfile if possible. Also find a way to make the github workflows more colourful and there is distinct and visual separation betwen each stage of the github workflow.

8. Finally speaking of the github workflow, perform an identical build process for the custom image similar to the github workflow locally in zcode. If you encounter that the build failed mid-process, you must not stop your tasks. You must determine what caused this failure and fix it asap. Search the web and think longer for fixing the failure during mid-build. After the errors and issues causing the failure have been dealth with, you must continue the local build, not from scratch, but from the built-up cache (until any build failure) and continue the build process from there. You must repeat this for any failure that might occure mid-build process until the build process is complete.

For the above tasks, you must think longer and you must make sure you have the latest information till September 18, 2026. Now good luck, champ ! You got this.
