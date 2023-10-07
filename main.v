import term.ui as tui
import os

struct App {
mut:
    tui &tui.Context = unsafe { nil }

	text string = 'Hello from V!'
	actual_path string = os.abs_path("")
	actual_i int
	dir_list []string
}

fn event(e &tui.Event, x voidptr) {
	mut app := unsafe { &App(x) }
    if e.typ == .key_down {
		match e.code {
			.up {app.actual_i = if (app.actual_i-1) == -1 {app.dir_list.len-1} else {app.actual_i-1}}
			.down {app.actual_i = (app.actual_i+1)%app.dir_list.len}
			.left {app.text = 'left'}
			.right {app.text = 'right'}
			.escape {exit(0)}
			else {}
		} 
    }
}

fn frame(x voidptr) {
    mut app := unsafe { &App(x) }

    app.tui.clear()
    //app.tui.draw_rect(20, 6, 41, 10)
	app.dir_list = os.ls(app.actual_path) or {panic(err)}
	for i, file in app.dir_list{
		if i == app.actual_i{
			app.tui.set_bg_color(r: 63, g: 81, b: 181)
			app.tui.draw_text(0, i+1, "-$file-")
			app.tui.reset_bg_color()
		}else{
			app.tui.draw_text(0, i+1, file)
		}
	}
    
    app.tui.set_cursor_position(0, 0)

    app.tui.reset()
    app.tui.flush()
}

fn main() {
    mut app := &App{}
	// os.ls()
	// os.abs_path()
	// os.is_dir()
	// os.is_dir_empty()
	// os.is_file()
	/*
fn chdir(path string) !
chdir changes the current working directory to the new directory in path.

fn getwd() string
getwd returns the absolute path of the current directory.

fn dir(opath string) string
dir returns all but the last element of path, typically the path's directory.
After dropping the final element, trailing slashes are removed.
If the path is empty, dir returns ".". If the path consists entirely of separators, dir returns a single separator.
The returned path does not end in a separator unless it is the root directory.



	*/
    app.tui = tui.init(
        user_data: app
        event_fn: event
        frame_fn: frame
        hide_cursor: true
    )
    app.tui.run()!
}