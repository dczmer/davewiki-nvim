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
          " manually add each plugin dependency to rtp so we can load them from plenary tests.
          set rtp+=${pkgs.vimPlugins.nvim-cmp}
          set rtp+=${pkgs.vimPlugins.telescope-nvim}
          set rtp+=${pkgs.vimPlugins.telescope-fzf-native-nvim}
          set rtp+=${pkgs.vimPlugins.mattn-calendar-vim}
          set rtp+=${pkgs.vimPlugins.which-key-nvim}
          luafile ./scripts/init.lua
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
                nvim-cmp
                cmp-buffer
                cmp-path
                cmp-nvim-lsp
                cmp-nvim-lsp-signature-help
                telescope-nvim
                telescope-fzf-native-nvim
                vim-markdown
                mattn-calendar-vim
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
            ${neovimWrapped}/bin/nvim "$@"
          '';
          inherit runtimeInputs;
        };
      in
      {
        packages = {
          default = app;
          neovimWrapped = neovimWrapped;
        };
        apps = {
          default = {
            type = "app";
            program = "${app}/bin/nvim-pkms";
          };
          luacheck = {
            type = "app";
            program = "${pkgs.lua54Packages.luacheck}/bin/luacheck";
          };
          stylua = {
            type = "app";
            program = "${pkgs.stylua}/bin/stylua";
          };
        };
        devShells = {
          default = pkgs.mkShell {
            packages = runtimeInputs;
            shellHook = ''
              # enable opencode extra tools for this shell
              OPENCODE_ENABLE_EXA=1 exec zsh
            '';
          };
        };
      }
    );
}
