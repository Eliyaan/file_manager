module main

import term.ui as tui
import time
import os
import toml

/*
TODO :
find a way to redraw only the modified things (will enable the full custom bg)
Tabs
config : colors
refresh les dossiers
Protected files
Add file
Add dir
Suppr file/dir
Favorites files
Copier les fichiers/dossiers
Copier le path
Copier le path de l'elem
Launch programs (with extention name) (avec truc comme l'autocomplétion sous la barre de recherche)
launch programs in this folder
pouvoir mettre des commandes avec racourcis genre G = lazygit avec la possibilité spawn ou pas (donc remplacer temp le fm genre pour lazygit)
scroll si trop de files
config : choose your own border chars
*/

struct App {
mut:
	tui &tui.Context = unsafe { nil }

	actual_path string = os.abs_path('')
	actual_i    int
	dir_list    []string
	frame_nb    int
	last_event  string
	edit_mode string

	old_actual_path string
	old_actual_i    int
	old_edit_mode string

	chdir_error string

	associated_apps map[string]string 
}

fn event(e &tui.Event, x voidptr) {
	mut app := unsafe { &App(x) }
	app.chdir_error = ''
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
			.n {
				app.edit_mode = 'Name of the new folder:'
				app.last_event = 'new_dir'
			}
			.escape {
				exit(0)
			}
			else {}
		}
	}
}

fn (mut app App) render() {
	app.tui.clear()
	app.tui.set_bg_color(r: 0, g: 0, b: 0)
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
	app.tui.set_color(r: 255, g: 255, b: 255) // white font

	
	app.tui.draw_text(0, 0, '${app.actual_path}')
	// Draw the files
	app.tui.set_color(r: 186, g: 222, b: 255) // color for dirs
	mut encountered_file := -1
	if app.chdir_error == '' {
		for i, file in app.dir_list {
			if i + 3 < app.tui.window_height{	
				if os.is_dir(file) {
					if i == app.actual_i {
						app.tui.set_bg_color(r: 63, g: 81, b: 181)
						app.tui.draw_text(1, i + 3, '> ${file}')
						app.tui.set_bg_color(r: 0, g: 0, b: 0)
					} else {
						app.tui.draw_text(1, i + 3, '  ${file}')
					}
				} else {
					if encountered_file == -1 {
						app.tui.set_color(r: 255, g: 255, b: 255)
						encountered_file = i
					}
					if i == app.actual_i {
						app.tui.set_bg_color(r: 63, g: 124, b: 181)
						app.tui.draw_text(1, i + 4, '> ${file}')
						app.tui.set_bg_color(r: 0, g: 0, b: 0)
					} else {
						app.tui.draw_text(1, i + 4, '  ${file}')
					}
				}
			}
		}
		if app.dir_list.len == 0 {
			app.tui.draw_text(0, 3, 'Empty directory')
		} else {
			if encountered_file != -1 {
				app.tui.draw_text(1, encountered_file + 3, '-------------------')
			} else {
				app.tui.draw_text(1, app.dir_list.len + 3, '-------------------')
			}
			app.tui.draw_text(0, app.tui.window_height, '${
			(if !os.is_dir(app.dir_list[app.actual_i]) {
				space_nb(os.file_size(app.dir_list[app.actual_i]).str()) + 'o'
			} else {
				'Directory'
			}):-15} | Modified the ${(time.date_from_days_after_unix_epoch(int(os.file_last_mod_unix(app.dir_list[app.actual_i])) / 86400).ymmdd()):-15} | ${os.abs_path(app.dir_list[app.actual_i])}')
		}
	} else {
		app.tui.draw_text(1, 2, app.chdir_error)
	}

	// Draw the box around the files
	app.draw_box(0, 2, app.tui.window_width, app.tui.window_height-1)

	if app.edit_mode != "" {
		app.draw_box(app.tui.window_width/2-50, (app.tui.window_height-1)/2-2, app.tui.window_width/2+50, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/2-49, (app.tui.window_height-1)/2-1, app.edit_mode)
	}


	app.tui.set_bg_color(r: 255, g: 255, b: 255)

	app.tui.set_cursor_position(0, 0)

	app.tui.reset()
	app.tui.flush()
}

fn frame(x voidptr) {
	mut app := unsafe { &App(x) }
	mut ask_render := false
	app.frame_nb = (app.frame_nb + 1) % 3600
	if app.old_actual_path != app.actual_path {
		app.update_dir_list()
		ask_render = true
		app.actual_i = app.find_last_dir()
		app.old_actual_path = app.actual_path
	} else {
		if app.frame_nb % 360 == 0 {
		}
	}

	if app.old_actual_i != app.actual_i {
		ask_render = true
		app.old_actual_i = app.actual_i
	}else if app.old_edit_mode != app.edit_mode{
		ask_render = true
		app.old_edit_mode = app.edit_mode
	}

	if ask_render {
		app.render()
	}
}

fn (mut app App) initialisation() {
	app.tui.set_color(r: 255, g: 255, b: 255)
	app.update_dir_list()
	app.tui.set_bg_color(r: 0, g: 0, b: 0)
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
}

fn main() {
	mut app := &App{}

	config := toml.parse_file("config.toml") or {panic(err)}

	tmp_array := config.value('exts_n_paths').array().map(it.string())
	for i, elem in tmp_array{
		if i%2 == 0{
			app.associated_apps[elem] = tmp_array[i+1]
		}
	}



	// os.ls()
	// os.abs_path()
	// os.is_dir()
	// os.is_dir_empty()
	// os.is_file()
	/*
	os.file_ext(app.dir_list[app.actual_i])
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
