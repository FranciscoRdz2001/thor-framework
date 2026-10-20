# thor_cli example

`thor_cli` is the `thor` command. From a checkout of the repository:

```bash
dart pub global activate --source path packages/thor_cli

thor create shop        # a server app with its route table and a test
cd shop
thor dev                # serve it, rebuilding on every change
thor add page /about    # lib/modules/<module>/pages/about_page.dart and its route in the module's group
thor build              # release: build/server + build/public
thor doctor --fix       # check the project and apply the safe fixes
```

Inside the repository it also runs without installing:

```bash
dart run thor_cli:thor --help
```
