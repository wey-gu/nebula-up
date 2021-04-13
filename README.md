# Nebula-Up

`Nebula-Up` is an utitly PoC to enable developer and user to bootstrap an nebula-graph cluster with nebula-graph-studio(Web UI) and nebula-graph-console(Command UI) ready out of box in oneliner install, required packages will handled with `nebula-up` as well, including docker on Linux(Ubuntu/CentOS), macOS(including both Intel and M1 chip based), and Windows.

Also, it's optimized to leverage China Repo Mirrors(docker, brew, gitee, etc...) in case needed enable a smooth deployment for Mainland China users.

With Shell:

```bash
curl -fsSL https://github.com/wey-gu/nebula-up/raw/main/install.sh | bash
```
With PowerShell:
```powershell
iwr https://github.com/wey-gu/nebula-up/raw/main/install.ps1 -useb | iex
```

TBD:
- [ ] Finished Windows(Docker Desktop instead of the WSL 1&2 in initial phase) part, leveraging chocolatey package manager as homebrew was used in macOS
- [ ] Fully optimized for CN users
- [ ] With nebula-graph version specification support
- [ ] Packaging similar content into homebrew/chocolatey?
- [ ] With uninstall/cleanup support
