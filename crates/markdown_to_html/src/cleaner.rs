use html5ever::driver::ParseOpts;
use html5ever::parse_document;
use html5ever::tendril::TendrilSink;
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use std::io::Cursor;
use std::rc::Rc;

/// Zhihu has its own spec for HTML rendering, which requires some specific cleaning of the HTML structure.
/// The known issues include: `<\p>\n` and `<\pre>\n` would be rendered as `\n\n` instead of `\n`.
/// Using html5ever to parse the HTML and clean it up according to the spec. Which might be more
/// safer than using regex to replace the HTML structure.
pub fn clean_html_structure(html: &str) -> String {
  use html5ever::serialize::{serialize, SerializeOpts};
  use markup5ever_rcdom::SerializableHandle;

  let parse_opts = ParseOpts::default();
  let dom = parse_document(RcDom::default(), parse_opts)
    .from_utf8()
    .read_from(&mut Cursor::new(html))
    .unwrap();

  // Satisfying zhihu-flavored HTML spec
  clean_node(&dom.document);

  let mut bytes = vec![];
  serialize(
    &mut bytes,
    &SerializableHandle::from(dom.document.clone()),
    SerializeOpts::default(),
  )
  .unwrap();

  String::from_utf8(bytes).unwrap()
}

/// Cleans the HTML structure to remove trailing `\n` after any node and handles special cases.
fn clean_node(node: &Handle) {
  match &node.data {
    NodeData::Text { contents } => {
      let mut contents_mut = contents.borrow_mut();
      if contents_mut.ends_with('\n') {
        *contents_mut = contents_mut.trim_end_matches('\n').into();
      }
    }
    NodeData::Element { name, .. } => {
      if name.local.as_ref() == "code" {
        // Special handling for `<code>`: remove leading and trailing `\n`
        if let Some(parent) = node.parent.take() {
          let parent = parent.upgrade().unwrap();
          let children = parent.children.borrow();
          let mut found = false;

          for sibling in children.iter() {
            if found {
              if let NodeData::Text { contents } = &sibling.data {
                let mut contents_mut = contents.borrow_mut();
                if contents_mut.starts_with('\n') {
                  *contents_mut = contents_mut.trim_start_matches('\n').into();
                }
              }
              break;
            }

            if Rc::ptr_eq(sibling, node) {
              found = true;
            }
          }
        }
      }
    }
    _ => {}
  }

  // Recursively clean child nodes
  for child in node.children.borrow().iter() {
    clean_node(child);
  }
}
