use markdown_to_html::markdown_to_html;
use pulldown_cmark::Options;
use std::{fs, process::Output};

fn zhihu_options() -> Options {
  Options::ENABLE_STRIKETHROUGH
    | Options::ENABLE_TABLES
    | Options::ENABLE_TASKLISTS
    | Options::ENABLE_FOOTNOTES
    | Options::ENABLE_MATH
}

fn assert_md_html(input: &str, expected_output: &str) {
  let output = markdown_to_html(input, zhihu_options());
  assert_eq!(output, expected_output);
}

#[test]
fn test_markdown_to_html_link() {
  let input = "这个文章纯粹为了测试正在快速更新的插件[Zhihu on Neovim](https://github.com/pxwg/zhihu_neovim)的基本功能是否被正确实现。";
  let expected_output = r#"<html><head></head><body><p>这个文章纯粹为了测试正在快速更新的插件<a href="https://github.com/pxwg/zhihu_neovim">Zhihu on Neovim</a>的基本功能是否被正确实现。</p></body></html>"#;
  assert_md_html(input, expected_output);
}

#[test]
fn test_markdown_to_html_math_formula() {
  let input = "这是一个公式$\\sin (x) = \\cos (x)$：";
  let expected_output = r#"<html><head></head><body><p>这是一个公式<img eeimg="1" src="//www.zhihu.com/equation?tex=\sin (x) = \cos (x)" alt="\sin (x) = \cos (x)">：</p></body></html>"#;
  assert_md_html(input, expected_output);
}

#[test]
fn test_markdown_to_html_blockquote() {
  let input = "> **数学**是人类智慧的结晶，\n> Math is the language of the universe,\n>\n> --Paul Halmos\n> **现在的技术**使得数学计算变得更加高效，我们 *what can do in seconds*。";
  let expected_output = r#"<html><head></head><body><blockquote><p><strong>数学</strong>是人类智慧的结晶， Math is the language of the universe,</p><p>--Paul Halmos <strong>现在的技术</strong>使得数学计算变得更加高效，我们 <em>what can do in seconds</em>。</p></blockquote></body></html>"#;
  assert_md_html(input, expected_output);
}

#[test]
fn test_markdown_to_html_special_symbols() {
  let input = "特殊符号测试：`&`、`<`、`>`、`\"双引号\"`、`'单引号'`。";
  let expected_output = r#"<html><head></head><body><p>特殊符号测试：<code>&amp;</code>、<code>&lt;</code>、<code>&gt;</code>、<code>"双引号"</code>、<code>'单引号'</code>。</p></body></html>"#;
  assert_md_html(input, expected_output);
}

#[test]
fn test_markdown_to_html_ordered_list_nested() {
  let input = "1. 一级测试\n   1. 测试一下！\n   2. 测试二级列表\n      1. 三级列表测试\n         1. 四级列表测试\n2. 这是一个测试\n3. hellbchqwleld\n4. snwebqw";
  let expected_output = r#"<html><head></head><body><ol><li>一级测试</li><ol><li>测试一下！</li><li>测试二级列表</li><ol><li>三级列表测试</li><ol><li>四级列表测试</li></ol></ol></ol><li>这是一个测试</li><li>hellbchqwleld</li><li>snwebqw</li></ol></body></html>"#;
  assert_md_html(input, expected_output);
}

#[test]
fn test_markdown_to_html_unordered_list_nested() {
  let input = "- 一级测试\n  - 测试一下！\n  - 测试二级列表\n    - 三级列表测试\n      - 四级列表测试\n- 这是一个测试\n- hellbchqwleld\n- snwebqw";
  let expected_output = r#"<html><head></head><body><ul><li>一级测试</li><ul><li>测试一下！</li><li>测试二级列表</li><ul><li>三级列表测试</li><ul><li>四级列表测试</li></ul></ul></ul><li>这是一个测试</li><li>hellbchqwleld</li><li>snwebqw</li></ul></body></html>"#;
  assert_md_html(input, expected_output);
}
