module main

import term.ui as tui
import time
import os
import toml

const (
	start_path = os.abs_path('')
)

/*
TODO :
Protected files

FUN - config : colors
Copier les fichiers/dossiers
Copier le path
Copier le path de l'elem
pouvoir mettre des commandes avec racourcis genre G = lazygit avec la possibilité spawn ou pas (donc remplacer le fm genre pour lazygit pdt son utilisation)
scroll si trop de files
config : choose your own border chars
Launch programs (with extention name?) (avec truc comme l'autocomplétion sous la barre de recherche)
launch programs in this folder (pareil mais pour vsc par ex qui en a besoin)
help shortcuts like ? for ex

find a way to redraw only the modified things (will enable the full custom bg)
Tabs
appui sur a->z / 0->9 emmène sur le prochain fichier contenant cette lettre
si ctrl + 1->9  jump au fichier dans x 
fix le underscore quand on appuie sur un nb à l'edit d'un fichier
clear crash logs / no crashes
config: keybinds
add/suppr with short cut Favorites files
*/

struct App {
mut:
	tui &tui.Context = unsafe { nil }

	actual_path string = os.abs_path('')
	actual_i    int
	dir_list    []string
	fav_folders []string
	frame_nb    int
	last_event  string
	fav_mode bool
	fav_index int
	edit_mode string
	question_mode string
	question_answer bool
	edit_text string
	refresh bool
	sort_name string = "Sorted by name"

	old_actual_path string
	old_actual_i    int
	old_edit_mode string
	old_edit_text string
	old_question_mode string
	old_question_answer bool
	old_fav_mode bool
	old_fav_index int

	chdir_error string

	associated_apps map[string]string 
	key_binds map[string]string 
	bg_color []u8
	folder_highlight []u8
	choice_highlight []u8
	folder_font []u8
	file_highlight []u8
	fav_highlight []u8
}

fn event(e &tui.Event, x voidptr) {
	mut app := unsafe { &App(x) }
	app.chdir_error = ''
	if e.typ == .key_down {
		if app.edit_mode != ""{
			match e.code {
				.null {}
				.escape {
					app.edit_mode = ""
					app.edit_text = ""
					app.last_event = "escape edit"
				}
				.backspace {
					if app.edit_text.len > 0{
						app.edit_text = app.edit_text[0..app.edit_text.len-1]
					}
				}
				.underscore {
					app.edit_text += "_"
				}
				.period {
					app.edit_text += "."
				}
				.comma {
					app.edit_text += ","
				}
				.colon {
					app.edit_text += ":"
				}
				.slash {
					app.edit_text += "/"
				}
				.question_mark {
					app.edit_text += "?"
				}
				.exclamation {
					app.edit_text += "!"
				}
				.minus {
					app.edit_text += "-"
				}
				.space {
					app.edit_text += "_"
				}
				.semicolon {
					app.edit_text += ";"
				}
				.enter {
					if app.edit_mode == "Name of the new folder:" {
						os.mkdir(os.join_path_single(app.actual_path, app.edit_text)) or {er("mkdir $err")}
						app.update_dir_list()
						app.edit_text = ""
						app.edit_mode = ""
						app.last_event = "create folder escape edit"
					}else if app.edit_mode == "Name of the new file:" {
						mut f := os.create(os.join_path_single(app.actual_path, app.edit_text)) or {er("create file $err");os.File{}}
						f.close()
						app.update_dir_list()
						app.edit_text = ""
						app.edit_mode = ""
						app.last_event = "create file escape edit"
					}
				}
				else{
					app.edit_text += e.code.str()				
				}
			}
		} else if app.question_mode != "" {			
			match e.code {
				.right {app.question_answer = !app.question_answer}
				.left {app.question_answer = !app.question_answer}
				.enter {
					if app.question_answer{
						if app.question_mode == "Delete this file ?" {
							os.rm(os.join_path_single(app.actual_path, app.dir_list[app.actual_i])) or {er('rm $err')}
							app.update_dir_list()
							if app.dir_list.len > 0{
								app.actual_i = app.actual_i % app.dir_list.len
							}
							app.last_event = "deleted a file"
						}else{
							if app.question_mode == "Delete this folder ?" {
								os.rmdir_all(os.join_path_single(app.actual_path, app.dir_list[app.actual_i])) or {er('rmdir_all $err')}
								app.update_dir_list()
								if app.dir_list.len > 0{
									app.actual_i = app.actual_i % app.dir_list.len
								}
								app.last_event = "deleted a folder"
							}
						}
					}
					app.refresh = true
					app.question_mode = ''
					app.question_answer = false
				}
				.escape {
					app.question_mode = ""
					app.question_answer = false
					app.last_event = "escape question"
				}
				else{}
			}
		} else if app.fav_mode{
			match e.code {
				.escape {
					app.fav_index = 0
					app.fav_mode = false
				}
				.up {
					if app.fav_folders != [] {
						app.fav_index = if (app.fav_index - 1) == -1 {
								app.fav_folders.len - 1
							} else {
								app.fav_index - 1
							}
					}
					app.last_event = 'fav up'
				}
				.down {
					if app.fav_folders != [] {
						app.fav_index = (app.fav_index + 1) % app.fav_folders.len
					}
					app.last_event = 'fav down'
				}
				.enter {
					app.actual_path = app.fav_folders[app.fav_index]
					app.fav_index = 0
					app.fav_mode = false
					os.chdir(app.actual_path) or {
						er('go in fav ${err}')
						app.chdir_error = '${err}'
					}
					app.update_dir_list()
					if app.dir_list.len > 0{
						app.actual_i = app.actual_i % app.dir_list.len
					}
				}
				else{}
			}
		} else {
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
					if !e.modifiers.has(.shift) {
						app.edit_mode = 'Name of the new file:'
						app.last_event = 'new_file'
					}else{
						app.edit_mode = 'Name of the new folder:'
						app.last_event = 'new_dir'
					}
				}
				.r {
					app.update_dir_list()
					if app.dir_list.len > 0{
						app.actual_i = app.actual_i % app.dir_list.len
					}
					app.refresh = true
				}
				.delete {
					if app.dir_list != [] {
						if !os.is_dir(app.dir_list[app.actual_i]) {
							app.question_mode = "Delete this file ?"
						}else{
							if e.modifiers.has(.shift) {
								app.question_mode = "Delete this folder ?"
							}
						}
					}
				}
				.escape {
					exit(0)
				}
				.q {
					exit(0)
				}
				.f {
					app.fav_mode = true
				}
				else {
					if e.code.str() in app.key_binds {
						spawn os.execute(app.key_binds[e.code.str()])
						app.refresh = true
					}
				}
			}
		}
		
	}else if e.typ == .resized {
		app.refresh = true
	}
}

fn (mut app App) render() {
	app.tui.clear()
	app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
	app.tui.set_color(r: 255, g: 255, b: 255) // white font

	
	app.tui.draw_text(0, 0, '${app.actual_path}')
	// Draw the files
	app.tui.set_color(r: app.folder_font[0], g: app.folder_font[1], b: app.folder_font[2]) // color for dirs
	mut encountered_file := -1
	if app.chdir_error == '' {
		for i, file in app.dir_list {
			if i + 3 < app.tui.window_height{	
				if os.is_dir(file) {
					if i == app.actual_i {
						app.tui.set_bg_color(r: app.folder_highlight[0], g: app.folder_highlight[1], b: app.folder_highlight[2])
						app.tui.draw_text(1, i + 3, '> ${file}')
						app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
					} else {
						app.tui.draw_text(1, i + 3, '  ${file}')
					}
				} else {
					if encountered_file == -1 {
						app.tui.set_color(r: 255, g: 255, b: 255) // file font color
						encountered_file = i
					}
					if i == app.actual_i {
						app.tui.set_bg_color(r: app.file_highlight[0], g: app.file_highlight[1], b: app.file_highlight[2])
						app.tui.draw_text(1, i + 4, '> ${file}')
						app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
					} else {
						app.tui.draw_text(1, i + 4, '  ${file}')
					}
				}
			}
		}
		if app.dir_list.len == 0 {
			app.tui.draw_text(2, 3, 'Empty directory')
		} else {
			if encountered_file != -1 {
				app.tui.draw_text(1, encountered_file + 3, '-------------------')
			} else {
				app.tui.draw_text(1, app.dir_list.len + 3, '-------------------')
			}
			bottom_text := '${(if !os.is_dir(app.dir_list[app.actual_i]) {space_nb(os.file_size(app.dir_list[app.actual_i]).str()) + 'o'} else {'Directory'}):-15} | Modified the ${(time.date_from_days_after_unix_epoch(int(os.file_last_mod_unix(app.dir_list[app.actual_i])) / 86400).ymmdd()):-15} | ${os.abs_path(app.dir_list[app.actual_i])}'
			app.tui.draw_text(0, app.tui.window_height, if bottom_text.len > app.tui.window_width {bottom_text[0..app.tui.window_width]} else {bottom_text})
		}
	} else {
		app.tui.draw_text(1, 2, app.chdir_error)
	}
	app.tui.set_color(r: 255, g: 255, b: 255)

	// Draw the box around the files
	app.draw_box(0, 2, app.tui.window_width, app.tui.window_height-1)
	app.tui.draw_text(3, 2, app.sort_name)

	if app.edit_mode != "" {
		app.draw_box(app.tui.window_width/2-50, (app.tui.window_height-1)/2-2, app.tui.window_width/2+50, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/2-49, (app.tui.window_height-1)/2-1, app.edit_mode)
		app.tui.draw_text(app.tui.window_width/2-49, (app.tui.window_height-1)/2, app.edit_text)
	}else if app.question_mode != "" {
		app.draw_box(app.tui.window_width/2-15, (app.tui.window_height-1)/2-2, app.tui.window_width/2+15, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/2-9, (app.tui.window_height-1)/2-1, app.question_mode)
		if app.question_answer{
			app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
			app.tui.draw_text(app.tui.window_width/2-3, (app.tui.window_height-1)/2,"No")
			app.tui.set_bg_color(r: app.choice_highlight[0], g: app.choice_highlight[1], b: app.choice_highlight[2])
		}else{
			app.tui.set_bg_color(r: app.choice_highlight[0], g: app.choice_highlight[1], b: app.choice_highlight[2])
			app.tui.draw_text(app.tui.window_width/2-3, (app.tui.window_height-1)/2,"No")
			app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
		}
		app.tui.draw_text(app.tui.window_width/2, (app.tui.window_height-1)/2, "Yes")
		app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	}else if app.fav_mode {
		app.draw_box(app.tui.window_width/2-30, (app.tui.window_height-1)/2-10, app.tui.window_width/2+30, (app.tui.window_height-1)/2+10)
		app.tui.draw_text(app.tui.window_width/2-28, (app.tui.window_height-1)/2-10, "Favorites")
		for i, fav in app.fav_folders {
			if app.fav_index == i {
				app.tui.set_bg_color(r: app.fav_highlight[0], g: app.fav_highlight[1], b: app.fav_highlight[2])
			}
			app.tui.draw_text(app.tui.window_width/2-28, (app.tui.window_height-1)/2-9+i, fav)
			if app.fav_index == i {
				app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
			}
		}
	}

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
	if app.refresh{
		ask_render = true
		app.refresh = false
	}
	if app.old_actual_i != app.actual_i {
		ask_render = true
		app.old_actual_i = app.actual_i
	}else if app.old_edit_mode != app.edit_mode{
		ask_render = true
		app.old_edit_mode = app.edit_mode
	}else if app.old_edit_text != app.edit_text{
		ask_render = true
		app.old_edit_text = app.edit_text
	}else if app.old_question_answer != app.question_answer{
		ask_render = true
		app.old_question_answer = app.question_answer
	}else if app.old_question_mode != app.question_mode{
		ask_render = true
		app.old_question_mode = app.question_mode
	}else if app.old_fav_mode != app.fav_mode {
		ask_render = true
		app.old_fav_mode = app.fav_mode
	}else if app.old_fav_index != app.fav_index {
		ask_render = true
		app.old_fav_index = app.fav_index
	}

	if ask_render {
		app.render()
	}
}

fn (mut app App) initialisation() {
	app.tui.set_color(r: 255, g: 255, b: 255)
	app.update_dir_list()
	app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
}

fn main() {
	println(start_path)
	mut app := &App{}
	config := toml.parse_file("config.toml") or {er("Config file error $err"); println("juujuj"); toml.Doc{}}
	if config.value('exts_n_paths') == toml.Any(toml.Null{}) {
		er("read config file error")
	}	

	tmp_array := config.value('exts_n_paths').array().map(it.string())
	for i, elem in tmp_array{
		if i%2 == 0{
			app.associated_apps[elem] = tmp_array[i+1]
		}
	}
	app.fav_folders = config.value('favorite_folders').array().map(it.string())
	app.bg_color = config.value('bg_color').array().map(u8(it.int()))
	app.folder_highlight = config.value('folder_highlight').array().map(u8(it.int()))
	app.choice_highlight = config.value('choice_highlight').array().map(u8(it.int()))
	app.folder_font = config.value('folder_font').array().map(u8(it.int()))
	app.file_highlight = config.value('file_highlight').array().map(u8(it.int()))
	app.fav_highlight = config.value('fav_highlight').array().map(u8(it.int()))

	tmp_keybinds := config.value('keybinds').array().map(it.array())
	mut keybinds := [][]string{}
	for elem in tmp_keybinds {
		keybinds << elem.map(it.string())
	}
	for pair in keybinds {
		app.key_binds[pair[0]] = pair[1]
	}


	// os.ls()
	// os.abs_path()
	// os.is_dir()
	// os.is_dir_empty()
	// os.is_file()
	/*
	os.file_name(opath string) string
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
