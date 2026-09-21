local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node

return {
	s("dirToAttrs", {
		t({
			"inputs:",
			"inputs.baseLib.importPairsOfDirPath {",
			"  dirPath = ./.;",
			"  pred = x:",
			"    (dirOf x == ./.) && baseNameOf x != \"default.nix\";",
			"  inputsForImportPairs = inputs;",
			"  excludeDirectories = false;",
			"}",
		}),
	}),
}
