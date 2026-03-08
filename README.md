# Overview

This is a neovim plugin that implements a PKMS (Personal Knowledge Management System), similar to projects like Logseq or Obsidian.

Dependencies:
- telescope-nvim: Provides interface for searching and grepping for documents, tags, and links in the vault.
- nvim-cmp: Provides the auto-completion interface for inserting tags, filenames, and links.
- mattn-calendar-vim: Provides date and calendar features used for daily journals.
- (Optional) neo-tree-nvim: Provides a file-explorer interface.
- (Optional) which-key-nvim: All key mappings use a `desc` property to describe it's function, which will be used by which-key.

Overview:
- Configurable "root" directory via global variable `davewiki_root`.
- Fast searching with FZF and ripgrep telescope integration.
- Unstructured note taking system:
    * Most notes are taken in daily journal files, which live under `{davewiki_root}/journals`
    * "Tags" are short identifiers, starting with a `#`, which represent a thing or an idea. They are stored in a flat directory structure under `{davewiki_root}/tags`. Tags can have contents, but are mostly used to link multiple documents by finding the back-links for the tag file.
    * Structured, traditional notes can be stored in a hierarchical folder structure under `{davewiki_root}/notes`.
    * When a tag is inserted into a document, it will automatically be converted to a hyperlink to that file.
    * Content is written in "blocks" - reverse indentation indicates that the indented section is grouped with the tags in the section above (indentation level).
    * When we want to collect notes about a specific tag, we can search for all occurrences of that tag in files, and extract the blocks (and their child blocks) to compile a document with all notes relevant to that tag.
    * Search for "back-links" from any markdown file, including "tag" files.

# Implementation

This project uses a nix flake to provide a devShell with all of the required dependencies. Use `nix develop` or `nix run` to interact with the application.

The flake packages an instance of neovim along with the dependencies required for this project, and a simple configuration file to bootstrap the plugin environment.

This project uses `luacheck` for linting and `stylua` for auto-formatting files.
