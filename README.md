# hello ← GestaltX import

The previous YTPlusRPC project files were removed from this repository.

To make this repo an **exact** copy of [GestaltX](https://github.com/hello8383-spec/GestaltX), run this on your machine (requires write access):

```bash
git clone https://github.com/hello8383-spec/GestaltX.git gx-tmp
cd gx-tmp
git remote set-url origin https://github.com/hello8383-spec/hello.git
git push -u origin main --force
```

That force-pushes the full GestaltX tree (sources, assets, xcodeproj, localization, tests) into `hello`.

Alternatively, in GitHub UI: delete this `hello` repo, then rename `GestaltX` → `hello` under **Settings → General → Repository name**.
