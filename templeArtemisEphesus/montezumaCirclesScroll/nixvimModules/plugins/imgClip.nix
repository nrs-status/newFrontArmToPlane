# https://github.com/img-clip/img-clip.nvim
# `img-clip` pastes images from the system clipboard directly into the current
# buffer, saving them to disk and inserting markup (Markdown/LaTeX/Typst/...)
# that references them. It has a first-class nixvim module
# (`plugins.img-clip`), configured through `settings` below. Image files are
# stored next to the current file under `assets/` (relative to the buffer's
# directory) and referenced via a relative path, which keeps repositories
# self-contained. The `<Leader>p` keymap invokes the `PasteImage` command
# (it complements the `image.nvim` plugin, which *renders* in-buffer images,
# whereas img-clip *inserts* them).
{
  plugins.img-clip = {
    enable = true;
    settings = {
      default = {
        # store pasted images in an `assets' directory relative to the current
        # file, so that the saved image is next to the markup that references
        # it
        dir_path = "assets";
        file_name = "%Y-%m-%d-%H-%M-%S";
        use_absolute_path = false;
        relative_to_current_file = true;
        # insert the (relative) file path of the pasted image
        template = "$FILE_PATH";
      };
      filetypes = {
        markdown = {
          url_encode_path = true;
          # NOTE: the plugin substitutes UPPERCASE placeholders; lowercase
          # `$file_path`-style strings are inserted literally (see markup.lua)
          template = "![$FILE_NAME]($FILE_PATH)";
          download_images = false;
        };
      };
    };
  };

  keymaps = [
    {
      key = "<Leader>p";
      mode = [ "n" ];
      action = ":PasteImage<CR>";
      options.silent = true;
      options.desc = "Paste image from clipboard";
    }
  ];
}