{
  description = "Neovim-based Personal KMS";
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        customRC = ''
          luafile ./init.lua
        '';
        runtimeInputs = with pkgs; [
          ripgrep
          fd
          fzf
          lua54Packages.luacheck
          stylua
        ];
        neovimWrapped = pkgs.wrapNeovim pkgs.neovim-unwrapped {
          configure = {
            inherit customRC;
            packages.myVimPackage = with pkgs.vimPlugins; {
              start = [
                lz-n
                nvim-cmp
                cmp-buffer
                cmp-path
                cmp-nvim-lsp
                cmp-nvim-lsp-signature-help
                telescope-nvim
                telescope-fzf-native-nvim
                vim-markdown
                mattn-calendar-vim
                neo-tree-nvim
                #snacks-nvim
                which-key-nvim
                plenary-nvim
              ];
            };
          };
        };
        app = pkgs.writeShellApplication {
          name = "nvim-pkms";
          text = ''
            exec ${neovimWrapped}/bin/nvim "$@"
          '';
          inherit runtimeInputs;
        };
      in
      {
        packages = {
          default = app;
        };
        apps = {
          default = {
            type = "app";
            program = "${app}/bin/nvim-pkms";
          };
        };
        devShells = {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                opencode
              ]
              ++ runtimeInputs;
            shellHook = ''
              # enable opencode extra tools for this shell
              OPENCODE_ENABLE_EXA=1 exec zsh
            '';
          };
        };
      }
    );
}
