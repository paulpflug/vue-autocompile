# vue-autocompile package

Auto compile vue file on save.

---

Add the parameters on the first line of the vue file.

```
out (string): relative path to html file to create
compress (bool): compress JS file (defaults to true) # currently not supported
```

```
// out: .
```

```
// out: ../build/
```

```
// out: . ,compress: false
```

Uses the vue-compiler installation of your current project, but falls back to its own vue-compiler installation if there is none. Never uses a global one.

Vue-compiler is called over its own cli, so it runs in node and not in atom.

## License
Copyright (c) 2015 Paul Pflugradt
Licensed under the MIT license.
