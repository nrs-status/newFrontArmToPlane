Profiles contain strings instead of paths because as paths they are incorrect. They will be processed by the mkNixvim function to create proper paths.

The root of the paths in these module sets is assumed to be the nixvimModules directory.

WARNING: this file is special-cased by the mkNixvim function through its filename (README.md)
