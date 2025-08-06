mod util;
use mlua::{Lua, Result};
use pulldown_cmark::{html, CodeBlockKind, CowStr, Event, Options, Parser, Tag, TagEnd};
use util::clean_html_structure;

pub trait EventProcessor {
  fn process_inline_math(&self, text: &str) -> Event<'static>;
  fn process_display_math(&self, text: &str) -> Event<'static>;
  fn process_image_start(&mut self, dest_url: &str) -> Event<'static>;
  fn process_image_alt_text(&mut self, text: &str) -> Event<'static>;
  fn process_code_block_start(&mut self, kind: CodeBlockKind) -> Event<'static>;
  fn process_code_block_end(&mut self) -> Event<'static>;
  fn process_soft_break(&self, in_code_block: bool) -> Event<'static>;
  fn process_text(&self, text: &str, in_code_block: bool) -> Event<'static>;
}

pub struct MarkdownEventProcessor {
  in_code_block: bool,
  current_image_url: Option<String>,
}

impl MarkdownEventProcessor {
  pub fn new() -> Self {
    Self {
      in_code_block: false,
      current_image_url: None,
    }
  }
}

impl EventProcessor for MarkdownEventProcessor {
  fn process_inline_math(&self, text: &str) -> Event<'static> {
    let eq = text.replace("\n", "");
    Event::Html(
      format!(
        "<img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\" alt=\"{}\"/>",
        eq, eq
      )
      .into(),
    )
  }

  fn process_display_math(&self, text: &str) -> Event<'static> {
    let eq = text.replace("\n", "");
    Event::Html(
      format!(
        "<img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\\\\\" alt=\"{}\\\\\"/>",
        eq, eq
      )
      .into(),
    )
  }

  fn process_image_start(&mut self, dest_url: &str) -> Event<'static> {
    self.current_image_url = Some(dest_url.to_string());
    Event::Text("".into())
  }

  fn process_image_alt_text(&mut self, text: &str) -> Event<'static> {
    let dest_url = self.current_image_url.take().unwrap();
    let caption = text.to_string();
    Event::Html(
            format!(
                "<img src=\"{}\" data-caption=\"{}\" data-size=\"normal\" data-watermark=\"watermark\" data-original-src=\"{}\" data-watermark-src=\"\" data-private-watermark-src=\"\" />",
                dest_url, caption, dest_url
            )
            .into(),
        )
  }

  fn process_code_block_start(&mut self, kind: CodeBlockKind) -> Event<'static> {
    self.in_code_block = true;
    let lang = match kind {
      CodeBlockKind::Indented => "".to_string(),
      CodeBlockKind::Fenced(info) => info.trim().to_string(),
    };
    Event::Html(CowStr::from(format!("<pre lang=\"{}\"><code>", lang)))
  }

  fn process_code_block_end(&mut self) -> Event<'static> {
    self.in_code_block = false;
    Event::Html(CowStr::from("</code></pre>"))
  }

  fn process_soft_break(&self, in_code_block: bool) -> Event<'static> {
    if in_code_block {
      Event::Text("\n".into())
    } else {
      Event::Text(" ".into())
    }
  }

  fn process_text(&self, text: &str, in_code_block: bool) -> Event<'static> {
    if in_code_block {
      // Clone the text to avoid lifetime issues
      Event::Text(text.to_string().into())
    } else {
      let replaced_text = text.replace('\n', " ");
      Event::Html(replaced_text.into())
    }
  }
}

fn markdown_to_html(input: &str, options: Options) -> String {
  let parser = Parser::new_ext(input, options);
  let mut processor = MarkdownEventProcessor::new();

  let parser = parser.map(move |event| match event {
    Event::InlineMath(text) => processor.process_inline_math(&text),
    Event::DisplayMath(text) => processor.process_display_math(&text),
    Event::Start(Tag::Image { dest_url, .. }) => processor.process_image_start(&dest_url),
    Event::Text(text) if processor.current_image_url.is_some() => {
      processor.process_image_alt_text(&text)
    }
    Event::Start(Tag::CodeBlock(kind)) => processor.process_code_block_start(kind),
    Event::End(TagEnd::CodeBlock) => processor.process_code_block_end(),
    Event::SoftBreak => processor.process_soft_break(processor.in_code_block),
    Event::Text(text) => processor.process_text(&text, processor.in_code_block),
    _ => event.to_owned(),
  });

  let mut html_output = String::new();
  html::push_html(&mut html_output, parser);

  clean_html_structure(&html_output)
}

#[mlua::lua_module]
fn markdown_to_html_lib(lua: &Lua) -> Result<mlua::Table> {
  let exports = lua.create_table()?;
  let options = Options::ENABLE_STRIKETHROUGH
    | Options::ENABLE_TABLES
    | Options::ENABLE_TASKLISTS
    | Options::ENABLE_FOOTNOTES
    | Options::ENABLE_MATH;
  exports.set(
    "md_to_html",
    lua.create_function(move |_, markdown: String| Ok(markdown_to_html(&markdown, options)))?,
  )?;
  Ok(exports)
}
