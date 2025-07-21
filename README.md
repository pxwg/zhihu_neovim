# Zhihu on Neovim

Using [neovim](https://github.com/neovim/neovim) to level up your [zhihu](https://www.zhihu.com/) writing, inspired by [zhihu_obsidian](https://github.com/dongguaguaguagua/zhihu_obsidian).

## Installation
```lua
return {
  "pxwg/zhihu_neovim",
  build = "deploy.sh",
  ft = { "markdown" },
  main = "zhvim",
  opts = {},
}
```

## Usage

- Open a local markdown file in neovim;
- Saving your cookie in global variable `$ZHIVIM_COOKIES` or `vim.g.zhvim_cookies `, this plugin will use it to authenticate your zhihu account and never share it with anyone;
- Run `:ZhnvimInitDraft` to int/update the draft.

## Value
- Convert local markdown files into Zhihu articles and send them to the draft box.

## To-do
- Support editing Zhihu answers;
- Support direct publishing of Zhihu articles and answers (bypassing the draft box);
- Add [blink-cmp](https://github.com/Saghen/blink.cmp) to auto complete @(user name list) and # tags (c.f.: [zhihu_obsidian](https://github.com/dongguaguaguagua/zhihu_obsidian)).

## No-Value
- Reading Zhihu articles in neovim.
