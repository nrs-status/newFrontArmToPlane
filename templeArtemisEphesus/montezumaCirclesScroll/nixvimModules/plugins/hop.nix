#disabled while testing `flash`, might replace by `flash` entirely
# NOTE: a nix file consisting only of comments contains no expression and is a
# parse error, so an empty (i.e. disabled) module body is provided below.
{
#   plugins = {
#     #find-next-character motion
#     hop = { enable = true; };
#   };
#   keymaps = [
#     {
#       key = "f"; # used to activate the hop plugin
#       action.__raw = ''
#         function()
#           require'hop'.hint_char1({
#             direction = require'hop.hint'.HintDirection.AFTER_CURSOR,
#             current_line_only = false
#           })
#         end
#       '';
#       options.remap = true;
#     }
#     {
#       key = "F";
#       action.__raw = ''
#         function()
#           require'hop'.hint_char1({
#             direction = require'hop.hint'.HintDirection.BEFORE_CURSOR,
#             current_line_only = false
#           })
#         end
#       '';
#       options.remap = true;
#     }
#   ];
# }
#
}
