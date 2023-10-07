import term.ui as tui
import os

/*
TODO :
*/

struct App {
mut:
	tui &tui.Context = unsafe { nil }

	actual_path string = os.abs_path('')
	actual_i    int
	dir_list    []string
	frame_nb    int
	last_event  string

	old_actual_path string
	old_actual_i    int

	chdir_error string
}

fn er(problem string) {
	os.write_file('C:/Users/PACHECON/_cv/file_manager/error_logs', problem) or { panic(err) }
}

fn event(e &tui.Event, x voidptr) {
	mut app := unsafe { &App(x) }
	app.chdir_error = ""
	if e.typ == .key_down {
		match e.code {
			.up {
				if app.dir_list != [] {
					app.actual_i = if (app.actual_i - 1) == -1 {
						app.dir_list.len - 1
					} else {
						app.actual_i - 1
					}
				}
				app.last_event = 'up'
			}
			.down {
				if app.dir_list != [] {
					app.actual_i = (app.actual_i + 1) % app.dir_list.len
				}
				app.last_event = 'down'
			}
			.left {
				app.actual_path = os.abs_path(os.dir(app.actual_path) + '\\')
				os.chdir(app.actual_path) or {
					er('left chdir ${err} ${app.actual_path}')
					''
				}
				app.last_event = 'left'
			}
			.right {
				app.go_in()
			}
			.enter {
				app.go_in()
			}
			.escape {
				exit(0)
			}
			else {}
		}
	}
}

fn (mut app App) go_in() {
	if app.dir_list != [] {
		if os.is_dir(app.dir_list[app.actual_i]) {
			if app.actual_path[app.actual_path.len - 1].ascii_str() != '\\' {
				app.actual_path = '${app.actual_path}\\${app.dir_list[app.actual_i]}'
			} else {
				app.actual_path = '${app.actual_path}${app.dir_list[app.actual_i]}'
			}
			os.chdir(app.actual_path) or { er("go_in $err"); app.chdir_error = "$err"}
		}
	}
	app.last_event = 'go_in'
}

fn (mut app App) render() {
	app.tui.clear()

	// app.tui.draw_rect(20, 6, 41, 10)
	app.tui.draw_text(0, 0, '${app.actual_path}')
	mut encountered_file := -1
	app.tui.set_color(r: 186, g: 222, b: 255)
	if app.chdir_error == "" {
		for i, file in app.dir_list {
			if os.is_dir(file) {
				if i == app.actual_i {
					app.tui.set_bg_color(r: 63, g: 81, b: 181)
					app.tui.draw_text(0, i + 3, '> ${file}')
					app.tui.reset_bg_color()
				} else {
					app.tui.draw_text(0, i + 3, '  ${file}')
				}
			} else {
				if encountered_file == -1 {
					app.tui.set_color(r: 255, g: 255, b: 255)
					encountered_file = i
				}
				if i == app.actual_i {
					app.tui.set_bg_color(r: 63, g: 124, b: 181)
					app.tui.draw_text(0, i + 4, '> ${file}')
					app.tui.reset_bg_color()
				} else {
					app.tui.draw_text(0, i + 4, '  ${file}')
				}
			}
		}
		if app.dir_list.len == 0 {
			app.tui.draw_text(0, 3, 'Empty directory')
		} else {
			if encountered_file != -1 {
				app.tui.draw_text(0, encountered_file + 3, '-------------------')
			} else {
				app.tui.draw_text(0, app.dir_list.len + 3, '-------------------')
			}
			app.tui.draw_text(0, app.tui.window_height, os.abs_path(app.dir_list[app.actual_i]))
		}
	}else{
		app.tui.draw_text(0, 2, app.chdir_error)
	}

	app.tui.set_cursor_position(0, 0)

	app.tui.reset()
	app.tui.flush()
}

fn (mut app App) find_last_dir() int {
	if app.last_event == 'left' {
		mut last_dir := app.old_actual_path[app.actual_path.len..]
		if last_dir[0].ascii_str() == '\\' {
			last_dir = last_dir[1..]
		}
		for i, elem in app.dir_list {
			if elem == last_dir {
				return i
			}
		}
		er(last_dir.str())
	}
	return 0
}

fn frame(x voidptr) {
	mut app := unsafe { &App(x) }
	mut ask_render := false
	app.frame_nb = (app.frame_nb + 1) % 30
	if app.old_actual_path != app.actual_path {
		app.update_dir_list()
		ask_render = true
		app.actual_i = app.find_last_dir()
		app.old_actual_path = app.actual_path
	} else {
		if app.frame_nb % 15 == 0 {
			app.update_dir_list()
		}
	}

	if app.old_actual_i != app.actual_i {
		ask_render = true
		app.old_actual_i = app.actual_i
	}

	if ask_render {
		app.render()
	}
}

fn (mut app App) update_dir_list() {
	app.dir_list = os.ls(app.actual_path) or { panic(err) }
	custom_sort_fn := fn (a &string, b &string) int {
		// return -1 when a comes before b
		// return 0, when both are in same order
		// return 1 when b comes before a
		if os.is_dir(os.abs_path(a)) == os.is_dir(os.abs_path(b)) {
			if a < b {
				return -1
			}
			if a > b {
				return 1
			}
			return 0
		}
		if int(os.is_dir(os.abs_path(a))) > int(os.is_dir(os.abs_path(b))) {
			return -1
		} else if int(os.is_dir(os.abs_path(a))) < int(os.is_dir(os.abs_path(b))) {
			return 1
		}
		return 0
	}
	app.dir_list.sort_with_compare(custom_sort_fn)
	//app.dir_list.sort(a<b)
	//app.dir_list.sort(|a, b| int(os.is_dir(os.abs_path(a))) >= int(os.is_dir(os.abs_path(b))))
	
}

fn (mut app App) initialisation() {
	app.tui.set_color(r: 255, g: 255, b: 255)
	app.update_dir_list()
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
	app.initialisation()
	app.tui.run()!
}
