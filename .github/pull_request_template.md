## halcyon — lean Hyprland gaming desktop on fedora-bootc

Thank you for contributing!

- Read [AGENTS.md](../blob/container/AGENTS.md) first — it documents the build
  architecture rules (stage order, repo lifecycle, per-stage verification,
  bootc constraints) that every change must respect.
- Run `just check` and `just lint` locally before opening the PR; the `lint`
  workflow runs exactly those two gates.
- Use a [semantic](https://www.conventionalcommits.org) PR title
  (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, …) — `semantic.yml`
  enforces it on title only.
- Changes under `build_files/` cost a full ~40-minute CI build on mistake —
  double-check package names against `packages.json` groups.

### Checklist

- [ ] `just check` / `just lint` pass locally
- [ ] New install stage has a `<stage>-verify` companion wired into the same RUN
- [ ] Third-party repos enabled and disabled within the same stage
- [ ] Nothing new lands in `/var`, `/opt`, `/usr/local` or `/boot`
- [ ] Comments explaining *why* are preserved
