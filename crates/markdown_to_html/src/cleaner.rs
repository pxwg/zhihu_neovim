use html5ever::driver::ParseOpts;
use html5ever::parse_document;
use html5ever::tendril::TendrilSink;
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use std::io::Cursor;
use std::rc::Rc;

/// ## Problem 1: unexpected `\n`
/// Zhihu has its own spec for HTML rendering, which requires some specific cleaning of the HTML structure.
/// The known issues include: `<\p>\n` and `<\pre>\n` would be rendered as `\n\n` instead of `\n`.
///
/// ## Problem 2: wrapped `<p>` tag
/// Moreover, Zhihu does not fully support HTML5, so we need to clean up the HTML structure e.g.
/// while `<p>` tags are used to wrap inline elements like `<img>`, `<a>`, `<span>`, `<code>`, `<em>`, and `<strong>`, we need to unwrap them manually.
///
/// ## Problem 3: nested lists
/// Zhihu does not fully support nested lists, so we need to restructure the HTML to move `<ul>` or
/// `<ol>` elements that are direct children of `<li>` elements to be siblings instead.
pub fn clean_html_structure(html: &str) -> String {
  use html5ever::serialize::{serialize, SerializeOpts};
  use markup5ever_rcdom::SerializableHandle;

  let parse_opts = ParseOpts::default();
  let dom = parse_document(RcDom::default(), parse_opts)
    .from_utf8()
    .read_from(&mut Cursor::new(html))
    .unwrap();

  // First pass: collect nodes that need unwrapping
  let mut nodes_to_unwrap = Vec::new();
  collect_nodes_to_unwrap(&dom.document, &mut nodes_to_unwrap);

  // Second pass: unwrap collected nodes
  for (parent, p_node, child) in nodes_to_unwrap {
    unwrap_p_tag(&parent, &p_node, &child);
  }

  // Third pass: restructure nested lists
  restructure_nested_lists(&dom.document);

  // Fourth pass: clean text nodes
  clean_text_nodes(&dom.document);

  let mut bytes = vec![];
  serialize(
    &mut bytes,
    &SerializableHandle::from(dom.document.clone()),
    SerializeOpts::default(),
  )
  .unwrap();

  String::from_utf8(bytes).unwrap()
}

/// Restructure nested lists to move <ul>/<ol> from inside <li> to sibling level
fn restructure_nested_lists(node: &Handle) {
  let mut lists_to_move = Vec::new();
  collect_nested_lists(node, &mut lists_to_move);

  // Move collected nested lists
  for (parent_ul, li_node, nested_list) in lists_to_move {
    move_nested_list_to_sibling(&parent_ul, &li_node, &nested_list);
  }

  // Recursively process children
  for child in node.children.borrow().iter() {
    restructure_nested_lists(child);
  }
}

/// Collect <ul>/<ol> nodes that are direct children of <li> nodes
fn collect_nested_lists(node: &Handle, lists_to_move: &mut Vec<(Handle, Handle, Handle)>) {
  if let NodeData::Element { name, .. } = &node.data {
    if name.local.as_ref() == "li" {
      // Find parent <ul> or <ol>
      if let Some(parent_weak) = node.parent.take() {
        if let Some(parent) = parent_weak.upgrade() {
          if let NodeData::Element {
            name: parent_name, ..
          } = &parent.data
          {
            if matches!(parent_name.local.as_ref(), "ul" | "ol") {
              // Look for nested <ul> or <ol> children in this <li>
              let children = node.children.borrow();
              for child in children.iter() {
                if let NodeData::Element {
                  name: child_name, ..
                } = &child.data
                {
                  if matches!(child_name.local.as_ref(), "ul" | "ol") {
                    lists_to_move.push((parent.clone(), node.clone(), child.clone()));
                  }
                }
              }
            }
          }
        }
        node.parent.set(Some(parent_weak));
      }
    }
  }

  // Recursively check children
  for child in node.children.borrow().iter() {
    collect_nested_lists(child, lists_to_move);
  }
}

/// Move a nested list from inside <li> to be a sibling after the <li>
fn move_nested_list_to_sibling(parent_ul: &Handle, li_node: &Handle, nested_list: &Handle) {
  // Remove nested list from <li>
  {
    let mut li_children = li_node.children.borrow_mut();
    li_children.retain(|child| !Rc::ptr_eq(child, nested_list));
  }

  // Insert nested list as sibling after <li> in parent <ul>
  {
    let mut parent_children = parent_ul.children.borrow_mut();
    if let Some(li_pos) = parent_children.iter().position(|n| Rc::ptr_eq(n, li_node)) {
      // Update nested list's parent reference
      nested_list.parent.set(Some(Rc::downgrade(parent_ul)));

      // Insert nested list right after the <li>
      parent_children.insert(li_pos + 1, nested_list.clone());
    }
  }
}

/// Collect all <p> nodes that should be unwrapped
fn collect_nodes_to_unwrap(node: &Handle, nodes_to_unwrap: &mut Vec<(Handle, Handle, Handle)>) {
  if let NodeData::Element { name, .. } = &node.data {
    if name.local.as_ref() == "p" {
      let children = node.children.borrow();
      if children.len() == 1 {
        if let Some(child) = children.first() {
          if let NodeData::Element {
            name: child_name, ..
          } = &child.data
          {
            if matches!(
              child_name.local.as_ref(),
              "img" | "a" | "span" | "code" | "em" | "strong"
            ) {
              if let Some(parent_weak) = node.parent.take() {
                if let Some(parent) = parent_weak.upgrade() {
                  nodes_to_unwrap.push((parent, node.clone(), child.clone()));
                }
                node.parent.set(Some(parent_weak));
              }
            }
          }
        }
      }
    }
  }

  // Recursively check children
  for child in node.children.borrow().iter() {
    collect_nodes_to_unwrap(child, nodes_to_unwrap);
  }
}

/// Unwrap a single <p> tag by replacing it with its child
fn unwrap_p_tag(parent: &Handle, p_node: &Handle, child: &Handle) {
  let mut parent_children = parent.children.borrow_mut();

  if let Some(pos) = parent_children.iter().position(|n| Rc::ptr_eq(n, p_node)) {
    // Update child's parent reference
    child.parent.set(Some(Rc::downgrade(parent)));
    parent_children[pos] = child.clone();
  }
}

/// Clean text nodes to remove trailing newlines
fn clean_text_nodes(node: &Handle) {
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
        if let Some(parent_weak) = node.parent.take() {
          if let Some(parent) = parent_weak.upgrade() {
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
            node.parent.set(Some(parent_weak));
          }
        }
      }
    }
    _ => {}
  }

  // Recursively clean child nodes
  for child in node.children.borrow().iter() {
    clean_text_nodes(child);
  }
}
