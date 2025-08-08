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

#[derive(Default)]
pub struct ImageState {
  pub url: Option<String>,
  pub alt: Option<String>,
}

#[derive(Default)]
pub struct CodeBlockState {
  pub active: bool,
  pub content: Option<String>,
  pub info: Option<String>,
}

#[derive(Default)]
pub struct TableState {
  pub in_head: bool,
  pub headers: Vec<String>,
  pub current_row: Vec<String>,
  pub rows: Vec<Vec<String>>,
  pub current_cell_content: String,
  pub collecting: bool,
}

impl TableState {
  fn reset(&mut self) {
    *self = Self::default();
  }

  fn start_collecting(&mut self) {
    self.collecting = true;
    self.headers.clear();
    self.rows.clear();
  }

  fn add_cell_content(&mut self, content: &str) {
    self.current_cell_content.push_str(content);
  }

  fn finish_cell(&mut self) {
    let content = std::mem::take(&mut self.current_cell_content);
    if self.in_head {
      self.headers.push(content);
    } else {
      self.current_row.push(content);
    }
  }

  fn finish_row(&mut self) {
    if !self.in_head && !self.current_row.is_empty() {
      self.rows.push(std::mem::take(&mut self.current_row));
    }
  }

  fn get_headers_refs(&self) -> Vec<&str> {
    self.headers.iter().map(|s| s.as_str()).collect()
  }

  fn get_rows_refs(&self) -> Vec<Vec<&str>> {
    self
      .rows
      .iter()
      .map(|row| row.iter().map(|s| s.as_str()).collect())
      .collect()
  }
}

pub struct MarkdownEventProcessor {
  pub image_state: ImageState,
  pub code_block_state: CodeBlockState,
  pub table_state: TableState,
}

impl MarkdownEventProcessor {
  pub fn new() -> Self {
    Self {
      image_state: ImageState::default(),
      code_block_state: CodeBlockState::default(),
      table_state: TableState::default(),
    }
  }

  pub fn in_code_block(&self) -> bool {
    self.code_block_state.active
  }

  pub fn in_table_head(&self) -> bool {
    self.table_state.in_head
  }

  pub fn is_collecting_image(&self) -> bool {
    self.image_state.url.is_some()
  }

  pub fn is_collecting_table(&self) -> bool {
    self.table_state.collecting
  }
}

impl EventProcessor for MarkdownEventProcessor {
  fn process_inline_math(&self, text: &str) -> Event<'static> {
    let eq = text.replace(['\n', '\r'], "");
    Event::Html(
      format!(
        "<img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\" alt=\"{}\"/>",
        eq, eq
      )
      .into(),
    )
  }

  fn process_display_math(&self, text: &str) -> Event<'static> {
    let eq = text.replace(['\n', '\r'], "");
    Event::Html(
      format!(
        "<img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\\\\\" alt=\"{}\\\\\"/>",
        eq, eq
      )
      .into(),
    )
  }

  fn process_image_start(&mut self, dest_url: &str) -> Event<'static> {
    self.image_state.url = Some(dest_url.to_string());
    self.image_state.alt = Some(String::new());
    Event::Text("".into())
  }

  fn process_image_alt_text(&mut self, text: &str) -> Event<'static> {
    if let Some(ref mut alt) = self.image_state.alt {
      alt.push_str(text);
    }
    Event::Text("".into())
  }

  fn process_image_end(&mut self) -> Event<'static> {
    let dest_url = self.image_state.url.take().unwrap();
    let caption = self.image_state.alt.take().unwrap_or_default();
    Event::Html(
            format!(
                "<img src=\"{}\" data-caption=\"{}\" data-size=\"normal\" data-watermark=\"watermark\" data-original-src=\"{}\" data-watermark-src=\"\" data-private-watermark-src=\"\" />",
                dest_url, caption, dest_url
            )
            .into(),
        )
  }

  fn process_code_block_start(&mut self, kind: CodeBlockKind) -> Event<'static> {
    self.code_block_state.active = true;
    let lang = match kind {
      CodeBlockKind::Indented => "".to_string(),
      CodeBlockKind::Fenced(info) => info.trim().to_string(),
    };
    Event::Html(CowStr::from(format!("<pre lang=\"{}\">", lang)))
  }

  fn process_code_block_end(&mut self) -> Event<'static> {
    self.code_block_state.active = false;
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

    // Add header row
    if !headers.is_empty() {
      table_html.push_str("<tr>");
      for header in headers {
        table_html.push_str(&format!("<th>{}</th>", header));
      }
      table_html.push_str("</tr>");
    }

    // Add data rows
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
    Event::Text(text) if processor.is_collecting_image() => processor.process_image_alt_text(&text),
    Event::End(TagEnd::Image) => processor.process_image_end(),
    Event::Start(Tag::CodeBlock(kind)) => processor.process_code_block_start(kind),
    Event::End(TagEnd::CodeBlock) => processor.process_code_block_end(),
    Event::SoftBreak => processor.process_soft_break(processor.in_code_block()),
    Event::Text(text) if processor.is_collecting_table() => {
      processor.table_state.add_cell_content(&text);
      Event::Text("".into())
    }
    Event::Text(text) => processor.process_text(&text, processor.in_code_block()),
    Event::Start(Tag::Table(_)) => {
      processor.table_state.start_collecting();
      Event::Text("".into())
    }
    Event::End(TagEnd::Table) => {
      let headers = processor.table_state.get_headers_refs();
      let rows = processor.table_state.get_rows_refs();
      let table_event = processor.process_table(headers, rows);
      processor.table_state.reset();
      table_event
    }
    Event::Start(Tag::TableHead) => {
      processor.table_state.in_head = true;
      Event::Text("".into())
    }
    Event::End(TagEnd::TableHead) => {
      processor.table_state.in_head = false;
      Event::Text("".into())
    }
    Event::Start(Tag::TableRow) => Event::Text("".into()),
    Event::End(TagEnd::TableRow) => {
      processor.table_state.finish_row();
      Event::Text("".into())
    }
    Event::Start(Tag::TableCell) => Event::Text("".into()),
    Event::End(TagEnd::TableCell) => {
      processor.table_state.finish_cell();
      Event::Text("".into())
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
