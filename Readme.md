# Odin Package Manager

Odin Package Manager (opm) is a small toolset for managing some odin packages. Currently it doesnt do much and there is no ecosystem around it.

Currently is only set up for MacOS but it's tiny so if you want to put in all the nessecities for windows I bet it'd be easy.

### Bring your own packages

It's not a command line tool. It's a library you can use in another odin program to do whatever you want.
opm will create directories and get packages from github for you currently. You can then import them directly or add them to your `collection` list in your `odin build` command.

Check out `demo/demo.odin` for a small example.

If you want your collections automatically used by odin, do what the demo does compile your package manager program and when building your main program do `odin build $(opm_executable collections)`

If you want to specify your packages in a plain text file you can do that too. Just make your package manager program read from some known file and call `opm.add_dep` for every listing however you want to do it. Your file can be json or toml or ini or ~~yaml~~ (don't use yaml).

If you want to skip some package for some reason add a `before_dep` function to your `OpmContext` it will call you back with the context and package. If you return true it will continue on processing the package, if you return false it will skip it.

If you want to run a command after a package has been installed pass an entire `OpmDep` struct to `add_dep` and specify `after_install`. It will give you the `OpmContext`, `OpmDep` and relative path to where the package was installed. Then you can do whatever you want with that info. Maybe run a makefile or something. IDK, I'm not your boss.

Comments and PRs are welcome BUT I want this library to be pretty light on what things it does outside of fetching packages and creating directories. Keep that in mind. Things like a specific text based `package.json` or `cargo.toml` are not going to end up in here. Things like: symlinking from disk or private git repos or repos on sites other than github are great additons.

---


This is an unoffial thing. Don't get your hopes up about its quality.
