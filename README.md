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

## Value
- Convert local markdown files into Zhihu articles and send them to the draft box.

## To-do
- Support editing Zhihu answers;
- Support direct publishing of Zhihu articles and answers (bypassing the draft box).

## No-Value
- Reading Zhihu articles in neovim.
