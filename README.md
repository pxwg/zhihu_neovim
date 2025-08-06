# Zhihu on Neovim

Using [neovim](https://github.com/neovim/neovim) to level up your [zhihu](https://www.zhihu.com/) writing, inspired by [zhihu_obsidian](https://github.com/dongguaguaguagua/zhihu_obsidian).

## Installation
```lua
return {
  "pxwg/zhihu_neovim",
  build = "deploy.sh",
  ft = { "markdown" },
  main = "zhvim",
  ---@type ZhnvimConfigs
  opts = {
    patterns = { "*.typ" },
    ---Somehow some important file type could not be detected by `vim.filetype.match` defaultly, so we introduce this.
    extension = { typ = "typst" },
    script = {},
  },
}
```

## Usage

- Open a local file in neovim;
- Saving your cookie in global variable `$ZHIVIM_COOKIES` or `vim.g.zhvim_cookies `, this plugin will use it to authenticate your zhihu account and never share it with anyone;
- Run `:ZhihuDraft` to int/update the draft;
    - If the file type is `markdown`, this plugin will automatically detect it and convert it into a Zhihu-flavored HTML, then using the Zhihu API with your cookie to upload it to your draft box;
  - If the file type matches the `patterns` in the configuration, you need to using some scripts (`pandoc` may be useful) to convert it into [CommonMark](https://spec.commonmark.org/), then this plugin will convert it into Zhihu-flavored HTML and upload it to your draft box;
- Run `ZhihuOpen` to open the draft box in your browser;
- Run `:ZhihuSync` to enter the diff page, compare the differences between the Zhihu web version and the local Markdown file, and use Neovim's built-in `diff` feature to edit the differences.

## Value
- Convert local markdown files into Zhihu articles and send them to the draft box;
- Using user-defined scripts to convert other file types into Zhihu articles, then upload them to the draft box.
- Synchronizing Zhihu articles to local markdown files.

## To-do
- Support for Windows;
- Support editing Zhihu answers;
- Support direct publishing of Zhihu articles and answers (bypassing the draft box);
- Add [blink-cmp](https://github.com/Saghen/blink.cmp) to auto complete @(user name list) and # tags (c.f.: [zhihu_obsidian](https://github.com/dongguaguaguagua/zhihu_obsidian)).
- Develop and test a more robust conversion library to achieve 100% compatibility with Zhihu-flavored HTML.

## No-Value
- Reading Zhihu articles in neovim.
