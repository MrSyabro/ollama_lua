package = "ollama"
version = "dev-1"
source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
   homepage = "*** please enter a project homepage ***",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.2",
   "obj",
   "rest",
}
build = {
   type = "builtin",
   modules = { ollama = "ollama.lua" }
}
