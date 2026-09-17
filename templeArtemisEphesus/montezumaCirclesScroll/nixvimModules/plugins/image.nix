{
  plugins.image = {
    enable = true;
    settings = {
      backend = "kitty";
      integrations = {
        markdown.enabled = true;
        typst.enabled = true;
        neorg.enabled = true;
        syslang.enabled = true;
        html.enabled = false;
        css.enabled = false;
      };
      max_width_window_percentage = 100;
      max_height_window_percentage = 50;
      window_overlap_clear_enabled = true;
      hijack_file_patterns = [
        "*.png"
        "*.jpg"
        "*.jpeg"
        "*.gif"
        "*.webp"
        "*.avif"
      ];
    };
  };
}
