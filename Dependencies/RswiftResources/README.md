# RswiftResources (vendored)

These are the `RswiftResources` sources from [R.swift](https://github.com/mac-cain13/R.swift)
7.8.0 (`Sources/RswiftResources`), MIT licensed. See `LICENSE`.

## Why this is vendored

R.swift's own `RswiftLibrary` product cannot be linked into the app targets on
Xcode 16 and later. When the `RswiftGenerateInternalResources` build tool plugin
is attached to a target, Xcode builds the R.swift package for the host only (to
produce the `rswift` executable the plugin runs) and never builds
`RswiftResources` for the target platform. The plugin-generated
`R.generated.swift` then fails with:

```
error: no such module 'RswiftResources'
```

This is an upstream bug, reported as
[mac-cain13/R.swift#944](https://github.com/mac-cain13/R.swift/issues/944) and
[#930](https://github.com/mac-cain13/R.swift/issues/930), both still open with no
fix. 7.8.0 is the newest R.swift release.

## Why the target is named `RswiftResourcesVendored`

The R.swift package has to stay in the dependency graph so its plugin keeps
generating `R.generated.swift`, and it declares a target called
`RswiftResources` itself. SwiftPM requires target names to be unique across the
whole package graph, so this package cannot declare a target with that name:

```
multiple packages ('r.swift', 'rswiftresources') declare targets with a
conflicting name: 'RswiftResources'
```

The target is therefore called `RswiftResourcesVendored`, and the
`ManicEmuSideload` target passes

```
OTHER_SWIFT_FLAGS = $(inherited) -module-alias RswiftResources=RswiftResourcesVendored
```

so the `import RswiftResources` in the generated file resolves to this module.
That flag lives in the `SideloadRelease` build configuration.

## Updating

When R.swift is upgraded, replace `Sources/RswiftResourcesVendored` and
`LICENSE` with the files from the new tag, keeping the directory name. The
generated code and this module must come from the same R.swift version.
