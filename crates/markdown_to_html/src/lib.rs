use mlua::{Lua, Result};
use pulldown_cmark::{html, Event, Options, Parser};

fn markdown_to_html(input: &str, options: Options) -> String {
    let parser = Parser::new_ext(input, options);

    let parser = parser.map(|event| {
        match event {
            Event::InlineMath(text) => {
                let eq = text.to_string();
                Event::Html(format!(
                    "<span class=\"math\"><img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\" alt=\"{}\"/></span>",
                    eq, eq
                ).into())
            },
            Event::DisplayMath(text) => {
                let eq = format!("{}\\\\", text);
                Event::Html(format!(
                    "<div class=\"math\"><img eeimg=\"1\" src=\"//www.zhihu.com/equation?tex={}\" alt=\"{}\"/></div>",
                    eq, text
                ).into())
            },
            _ => event,
        }
    });

    let mut html_output = String::new();
    html::push_html(&mut html_output, parser);
    html_output.replace("\n", "")
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
