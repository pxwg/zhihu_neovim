mod cleaner;
use cleaner::clean_html_structure;
use mlua::{Lua, Result};
use pulldown_cmark::{html, CodeBlockKind, CowStr, Event, Options, Parser, Tag, TagEnd};

pub trait EventProcessor {
  fn process_inline_math(&self, text: &str) -> Event<'static>;
  fn process_display_math(&self, text: &str) -> Event<'static>;
  fn process_image_start(&mut self, dest_url: &str) -> Event<'static>;
  fn process_image_alt_text(&mut self, text: &str) -> Event<'static>;
  fn process_image_end(&mut self) -> Event<'static>;
  fn process_code_block_start(&mut self, kind: CodeBlockKind) -> Event<'static>;
  fn process_code_block_end(&mut self) -> Event<'static>;
  fn process_soft_break(&self, in_code_block: bool) -> Event<'static>;
  fn process_text(&self, text: &str, in_code_block: bool) -> Event<'static>;
  fn process_table(&self, headers: Vec<&str>, rows: Vec<Vec<&str>>) -> Event<'static>;
}

pub struct MarkdownEventProcessor {
  pub in_code_block: bool,
  pub current_image_url: Option<String>,
  pub current_image_alt: Option<String>,
  pub code_block_content: Option<String>,
  pub code_block_info: Option<String>,
  pub in_table_head: bool,
}

impl MarkdownEventProcessor {
  pub fn new() -> Self {
    Self {
      in_code_block: false,
      current_image_url: None,
      current_image_alt: None,
      code_block_content: None,
      code_block_info: None,
      in_table_head: false,
    }
  }
}

impl EventProcessor for MarkdownEventProcessor {
  fn process_inline_math(&self, text: &str) -> Event<'static> {
    let eq = text.replace("\n", "").replace("\r", "");
    Event::Html(
      format!(
        "<img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\" alt=\"{}\"/>",
        eq, eq
      )
      .into(),
    )
  }

  fn process_display_math(&self, text: &str) -> Event<'static> {
    let eq = text.replace("\n", "").replace("\r", "");
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
    self.current_image_alt = Some(String::new());
    Event::Text("".into())
  }

  fn process_image_alt_text(&mut self, text: &str) -> Event<'static> {
    if let Some(ref mut alt) = self.current_image_alt {
      alt.push_str(text);
    }
    Event::Text("".into())
  }

  fn process_image_end(&mut self) -> Event<'static> {
    let dest_url = self.current_image_url.take().unwrap();
    let caption = self.current_image_alt.take().unwrap_or_default();
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
    Event::Html(CowStr::from(format!("<pre lang=\"{}\">", lang)))
  }

  fn process_code_block_end(&mut self) -> Event<'static> {
    self.in_code_block = false;
    Event::Html(CowStr::from("</pre>"))
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

  fn process_table(&self, headers: Vec<&str>, rows: Vec<Vec<&str>>) -> Event<'static> {
    let mut table_html = String::from(
      "<table data-draft-node=\"block\" data-draft-type=\"table\" data-size=\"normal\"><tbody>",
    );

    table_html.push_str("<tr>");
    for header in headers {
      table_html.push_str(&format!("<th>{}</th>", header));
    }
    table_html.push_str("</tr>");

    for row in rows {
      table_html.push_str("<tr>");
      for cell in row {
        table_html.push_str(&format!("<td>{}</td>", cell));
      }
      table_html.push_str("</tr>");
    }

    table_html.push_str("</tbody></table>");

    Event::Html(table_html.into())
  }
}

pub fn markdown_to_html(input: &str, options: Options) -> String {
  let parser = Parser::new_ext(input, options);
  let mut processor = MarkdownEventProcessor::new();

  let parser = parser.map(move |event| match event {
    Event::InlineMath(text) => processor.process_inline_math(&text),
    Event::DisplayMath(text) => processor.process_display_math(&text),
    Event::Start(Tag::Image { dest_url, .. }) => processor.process_image_start(&dest_url),
    Event::Text(text) if processor.current_image_url.is_some() => {
      processor.process_image_alt_text(&text)
    }
    Event::End(TagEnd::Image) => processor.process_image_end(),
    Event::Start(Tag::CodeBlock(kind)) => processor.process_code_block_start(kind),
    Event::End(TagEnd::CodeBlock) => processor.process_code_block_end(),
    Event::SoftBreak => processor.process_soft_break(processor.in_code_block),
    Event::Text(text) => processor.process_text(&text, processor.in_code_block),
    Event::Start(Tag::Table(_)) => {
      let html =
        r#"<table data-draft-node="block" data-draft-type="table" data-size="normal"><tbody>"#;
      Event::Html(html.into())
    }
    Event::End(TagEnd::Table) => Event::Html("</tbody></table>".into()),
    Event::Start(Tag::TableHead) => {
      processor.in_table_head = true;
      Event::Text("".into())
    }
    Event::End(TagEnd::TableHead) => {
      processor.in_table_head = false;
      Event::Text("".into())
    }
    Event::Start(Tag::TableRow) => Event::Html("<tr>".into()),
    Event::End(TagEnd::TableRow) => Event::Html("</tr>".into()),
    Event::Start(Tag::TableCell) => {
      if processor.in_table_head {
        Event::Html("<th>".into())
      } else {
        Event::Html("<td>".into())
      }
    }
    Event::End(TagEnd::TableCell) => {
      if processor.in_table_head {
        Event::Html("</th>".into())
      } else {
        Event::Html("</td>".into())
      }
    }
    _ => event.to_owned(),
  });

  let mut html_output = String::new();
  html::push_html(&mut html_output, parser);

  let out = clean_html_structure(&html_output);
  out.replace("<br>\n", "")
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
